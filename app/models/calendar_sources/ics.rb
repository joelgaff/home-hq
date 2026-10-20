require "net/http"
require "icalendar"
require "icalendar/recurrence"

# The ICS adapter (plan: Calendars): any ICS/webcal URL, read-only. Parses the feed into event
# rows for a window: recurrence expanded (RRULE, EXDATE, moved occurrences by RECURRENCE-ID),
# cancelled events dropped, all-day events from midnight to an exclusive midnight end, floating
# times read in the household's zone, timed events with no end lasting an hour.
class CalendarSources::Ics
  class Invalid < StandardError; end
  class NotFound < Invalid
    def initialize(msg = "the feed answered 404") = super
  end

  SECRET_HINT = "copy the calendar's \"Secret address in iCal format\" from Google Calendar → Settings and sharing → Integrate calendar"

  MAX_BYTES = 5 * 1024 * 1024
  MAX_REDIRECTS = 5

  # Tests (and a console) can hand in a lambda that takes a URL and returns the body.
  class_attribute :fetcher, default: nil

  def initialize(source)
    @source = source
  end

  def fetch(url = @source.url, hops = 0)
    return fetcher.call(url) if fetcher
    uri = URI.parse(url)
    raise Invalid, "not an http(s) address" unless uri.is_a?(URI::HTTP)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 20) do |http|
      http.request(Net::HTTP::Get.new(uri, "User-Agent" => "HomeHQ calendar sync"))
    end
    case response
    when Net::HTTPSuccess
      raise Invalid, "feed larger than #{MAX_BYTES / 1024 / 1024} MB" if response.body.bytesize > MAX_BYTES
      response.body
    when Net::HTTPRedirection
      raise Invalid, "too many redirects" if hops >= MAX_REDIRECTS
      fetch(URI.join(url, response["location"]).to_s, hops + 1)
    when Net::HTTPNotFound
      raise NotFound
    else
      raise Invalid, "the feed answered #{response.code}"
    end
  end

  def parse(body, window)
    raise Invalid, "this address returned a web page, not a calendar feed" if body.to_s.lstrip[0, 200] =~ /\A(<!doctype html|<html)/i
    calendars = Icalendar::Calendar.parse(body.to_s)
    raise Invalid, "not a calendar (no VCALENDAR found)" if calendars.empty?
    zone = ActiveSupport::TimeZone[@source.household.time_zone] || Time.zone
    rows = []
    calendars.flat_map(&:events).group_by(&:uid).each do |uid, versions|
      next if uid.blank?
      masters, overrides = versions.partition { |e| e.recurrence_id.nil? }
      moved = overrides.index_by { |e| to_time(e.recurrence_id, zone).to_i }
      masters.each do |master|
        occurrences_of(master, window, zone).each do |starts_at, ends_at|
          override = moved.delete(starts_at.to_i)
          rows << row_for(override || master, uid, starts_at, ends_at, zone, override: override.present?)
        end
      end
      # Moved occurrences whose original start fell outside the window (or whose master is gone).
      moved.each_value { |e| rows << row_for(e, uid, *bounds_of(e, zone), zone, override: true) }
    end
    rows.compact.select { |r| r[:starts_at] < window.end && r[:ends_at] > window.begin }
  end

  private

  def row_for(event, uid, starts_at, ends_at, zone, override:)
    return nil if event.status.to_s.casecmp?("CANCELLED")
    starts_at, ends_at = bounds_of(event, zone) if override
    key = event.rrule.any? || override ? "#{uid}/#{starts_at.utc.iso8601}" : uid
    { uid: key, title: event.summary.to_s.strip.presence || "(No title)", starts_at: starts_at, ends_at: ends_at,
      all_day: all_day?(event), location: event.location.to_s.strip.presence, notes: event.description.to_s.strip.presence }
  end

  def occurrences_of(event, window, zone)
    starts_at, ends_at = bounds_of(event, zone)
    return [ [ starts_at, ends_at ] ] if event.rrule.empty?
    length = ends_at - starts_at
    event.occurrences_between(window.begin - length, window.end).map do |occ|
      s = all_day?(event) ? zone.local(occ.start_time.year, occ.start_time.month, occ.start_time.day) : occ.start_time.in_time_zone(zone)
      [ s, s + length ]
    end
  end

  def bounds_of(event, zone)
    starts_at = to_time(event.dtstart, zone)
    ends_at = event.dtend ? to_time(event.dtend, zone) : nil
    if all_day?(event)
      starts_at = starts_at.beginning_of_day
      ends_at = ends_at ? ends_at.beginning_of_day : starts_at + 1.day
      ends_at = starts_at + 1.day if ends_at <= starts_at
    else
      ends_at ||= event.duration ? starts_at + duration_seconds(event.duration) : starts_at + 1.hour
      ends_at = starts_at + 1.hour if ends_at <= starts_at
    end
    [ starts_at, ends_at ]
  end

  def all_day?(event)
    event.dtstart.is_a?(Icalendar::Values::Date) || event.dtstart.ical_params["value"]&.first.to_s.casecmp?("DATE")
  end

  # An ICS value as a time in the household's zone: dates at midnight, UTC and zoned times as they
  # are, floating times (no TZID, no Z) as wall-clock time in the household's zone.
  def to_time(value, zone)
    case value
    when Icalendar::Values::Date then zone.local(value.year, value.month, value.day)
    when Icalendar::Values::DateTime
      if value.utc? || value.ical_params["tzid"].present?
        value.to_time.in_time_zone(zone)
      else
        zone.local(value.year, value.month, value.day, value.hour, value.minute, value.second)
      end
    else
      value.to_time.in_time_zone(zone)
    end
  end

  def duration_seconds(duration)
    duration.weeks * 7.days + duration.days * 1.day + duration.hours * 1.hour + duration.minutes * 1.minute + duration.seconds
  end
end
