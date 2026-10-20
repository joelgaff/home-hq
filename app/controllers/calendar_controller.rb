# The Calendar view (ui-spec §1.2): one mode (Today / 3 Day / Week / Month) on one date, served
# as the "calendar" Turbo Frame so navigation never leaves the page.
class CalendarController < ApplicationController
  MODES = %w[day 3day week month agenda].freeze

  def show
    @household = Current.household
    render partial: "calendar/calendar", locals: self.class.locals_from(params, @household), layout: false
  end

  # Mode, date and the phone's person chip (nil is Everyone) from the params; the live-sync
  # calendar piece uses the same reading.
  def self.locals_from(params, household)
    mode = MODES.include?(params[:mode]) ? params[:mode] : "day"
    date = parse_date(params[:date]) || Current.now.to_date
    date = date.beginning_of_month if mode == "month"
    { mode: mode, date: date, person: household.people.find_by(id: params[:person]) }
  end

  def self.parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
