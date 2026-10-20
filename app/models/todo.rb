# A one-off to-do (plan: People view): "pack swim bag", "library book back". For a person or
# Anyone (nil), optionally due on a day or at a time, optionally worth stars for a kid. Distinct
# from chores, which repeat with their routine. Done is a timestamp; undo clears it and takes the
# stars back.
class Todo < ApplicationRecord
  include SyncsPieces

  belongs_to :household
  belongs_to :person, optional: true
  belongs_to :done_by, class_name: "Person", optional: true
  has_many :star_entries, dependent: :destroy

  validates :title, presence: true
  validates :stars, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  before_validation { self.due_on ||= due_at&.in_time_zone&.to_date }
  syncs_pieces :"today-lanes", :"today-agenda", :chores, :people

  scope :open, -> { where(done_at: nil) }
  scope :for_person, ->(person) { where(person_id: person&.id) }

  def done? = done_at.present?
  def timed? = due_at.present?
  def anyone? = person_id.nil?

  def overdue?(today = Current.now.to_date)
    !done? && due_on.present? && due_on < today
  end

  # Done, by someone or nobody in particular; the stars go to the kid it is for, or the kid who did it.
  def complete!(by: nil)
    transaction do
      update!(done_at: Time.current, done_by: by)
      earner = person&.kid? ? person : (by&.kid? ? by : nil)
      earner.star_entries.create!(amount: stars, todo: self, note: title) if earner && stars.positive?
      AuditEntry.record("todo.completed", household: household, subject: self, subject_name: title, details: { "for" => (by || person)&.name }.compact)
    end
  end

  def undo!
    transaction do
      star_entries.destroy_all
      update!(done_at: nil, done_by: nil)
    end
  end

  # "4 PM" for a timed one, "Today", "Overdue" or nothing.
  def when_label(today = Current.now.to_date)
    return I18n.l(due_at.in_time_zone, format: :time_short) rescue due_at.in_time_zone.strftime("%-l:%M %p") if timed?
    return "Overdue" if overdue?(today)
    due_on == today ? "Today" : nil
  end
end
