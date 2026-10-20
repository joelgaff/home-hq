# A repeating job in a routine, for one person or for Anyone (no person). Done-ness is a
# completion dated today, so every chore resets itself at midnight (plan: Persistence).
class Chore < ApplicationRecord
  include Audited
  include SyncsPieces
  include Scheduled
  include Positioned

  belongs_to :household
  syncs_pieces :chores, :"today-chores"
  belongs_to :routine
  belongs_to :person, optional: true
  has_many :completions, class_name: "ChoreCompletion", dependent: :destroy
  # Preloadable "done today": `includes(:completions_today)` answers done? for a whole list at once.
  has_many :completions_today, -> { where(completed_on: Current.now.to_date) }, class_name: "ChoreCompletion"
  after_commit { Current.chores_cache = nil }

  validates :title, presence: true
  audited "chore"
  validates :stars, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  before_validation { place_last(lane_siblings) if routine }

  # The list a chore is ordered within: its routine's lane (person or Anyone).
  def lane_siblings
    routine.chores.where(person_id: person_id).in_order
  end

  scope :in_order, -> { order(:position, :id) }
  scope :for_anyone, -> { where(person_id: nil) }

  def anyone? = person_id.nil?

  # Due on a day when the household is not paused, the routine runs that day, and the chore's
  # weekdays (if any) include it.
  def due_on?(date)
    !household.chores_paused?(date) && routine.active_on?(date) && on_weekday?(date)
  end

  # Overdue: due today, its routine already over, and not done (plan: Gap review answers).
  def overdue?(at: Current.now)
    due_on?(at.to_date) && routine.over_at?(at) && !done?
  end

  def completion_today
    completions_today.first
  end

  def done?
    completion_today.present?
  end

  def done_by
    completion_today&.person
  end

  # Marks the chore done now; kids' chores pay their stars to the owner, Anyone chores to
  # whoever did it (ui-spec §1.3). Returns the completion (undo it with `undo!`).
  def complete!(by: nil)
    transaction do
      completion = completions.create!(person: by, completed_on: Current.now.to_date)
      completions_today.reset
      AuditEntry.record("chore.completed", household: household, subject: self, details: { "for" => (by || person)&.name }.compact)
      if (earner = star_earner(by)) && stars.positive?
        earner.star_entries.create!(amount: stars, chore_completion: completion)
      end
      completion
    end
  end

  def star_earner(by)
    return person if person&.kid?
    by if by&.kid?
  end

  # Not-done first, overdue before the rest (ui-spec §1.3).
  def sort_key
    [ done? ? 1 : 0, overdue? ? 0 : 1, position, id ]
  end
end
