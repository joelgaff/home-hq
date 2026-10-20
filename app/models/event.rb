# A calendar entry. Timed events have a start and end; all-day events run from midnight to an
# exclusive midnight end so a three-day trip spans exactly three days (ui-spec §1.2). Travel time
# turns the start into a "leave by" that orders the Today hero.
class Event < ApplicationRecord
  include SyncsPieces

  belongs_to :household
  # Synced events carry their feed; events entered another way (the seeds) have none.
  belongs_to :calendar_source, optional: true
  # Listing order matters: the first person gives a shared event its colour (ui-spec §1.2).
  has_many :attendees, -> { order(:id) }, dependent: :destroy
  has_many :people, through: :attendees

  validates :title, presence: true
  validate :ends_after_start
  syncs_pieces :"today-hero", :"today-lanes", :"today-agenda", :calendar

  scope :timed, -> { where(all_day: false) }
  scope :all_day, -> { where(all_day: true) }
  scope :overlapping, ->(from, to) { where("starts_at < ? AND ends_at > ?", to, from) }
  scope :for_person, ->(person) { where(id: Attendee.where(person_id: person.id).select(:event_id)) }
  scope :by_start, -> { order(:starts_at, ends_at: :desc) }
  # Demo extras (the drawer's "Overloaded" day) are hidden unless that mode is on.
  scope :in_mode, ->(mode) { mode == "busy" ? all : where(demo_set: nil) }

  # Attendees in listing order (preloaded with `includes(attendees: :person)`).
  def attending_people
    attendees.map(&:person)
  end

  # Everyone's: every person attends, or nobody is listed (nothing to colour it by).
  def family?
    attendees.empty? || attendees.size >= household.people.size
  end

  def color_person
    family? ? household.family : attending_people.first
  end

  def leave_by
    travel_minutes.present? ? starts_at - travel_minutes.minutes : starts_at
  end

  def travel?
    travel_minutes.present? && travel_minutes.positive?
  end

  def duration_minutes
    ((ends_at - starts_at) / 60).round
  end

  def span_days
    ((ends_at - starts_at) / 1.day).round
  end

  # "Day N of M" for an all-day event spanning several days.
  def day_number_on(day)
    (((day.in_time_zone.beginning_of_day - starts_at) / 1.day).round + 1).clamp(1, span_days)
  end

  def continues_before?(day)
    starts_at < day.in_time_zone.beginning_of_day
  end

  def continues_after?(day)
    ends_at > day.in_time_zone.beginning_of_day + 1.day
  end

  # Replaces the attendees (listing order kept: the first gives the colour).
  def set_people!(list)
    transaction do
      attendees.destroy_all
      list.each { |p| attendees.create!(person: p) }
      attendees.reset
    end
  end

  # A manual "who is it for" (plan: Calendars, rule 1): kept across re-syncs until cleared.
  def override_people!(list)
    transaction do
      set_people!(list)
      update!(people_overridden: true)
    end
  end

  def clear_people_override!
    transaction do
      update!(people_overridden: false)
      calendar_source&.assign_people(self)
    end
  end

  def past?(at) = ends_at <= at
  def current?(at) = starts_at <= at && ends_at > at

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "must be after the start") if ends_at <= starts_at
  end
end
