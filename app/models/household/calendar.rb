# The calendar questions the views ask (ui-spec §1.1-1.2): what is on a day, what is next.
module Household::Calendar
  extend ActiveSupport::Concern

  included do
    has_many :events, dependent: :destroy
    has_many :calendar_sources, dependent: :destroy
  end

  # Timed events touching `day`, sorted by start (longer first on ties). `mode` is the demo
  # drawer's calendar data mode: "empty" hides today's timed events, "busy" adds the extras.
  def timed_events_on(day, person: nil, mode: Current.calendar_mode)
    return Event.none if mode == "empty" && day.to_date == Current.now.to_date
    scope = events.timed.in_mode(mode).overlapping(*day_bounds(day)).includes(attendees: :person).by_start
    scope = scope.for_person(person) if person
    scope
  end

  def all_day_events_on(day, person: nil, mode: Current.calendar_mode)
    scope = events.all_day.in_mode(mode).overlapping(*day_bounds(day)).includes(attendees: :person).by_start
    scope = scope.for_person(person) if person
    scope
  end

  # The next thing someone has to act on: the earliest upcoming leave-by today.
  def next_event(at: Current.now, mode: Current.calendar_mode)
    timed_events_on(at, mode: mode).select { |e| e.starts_at > at }.min_by(&:leave_by)
  end

  private

  def day_bounds(day)
    start = day.in_time_zone.beginning_of_day
    [ start, start + 1.day ]
  end
end
