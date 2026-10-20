# Geometry and copy for the calendar's time grid (ui-spec §1.2): 6 AM to 11 PM at 72 px per hour.
module CalendarHelper
  PX = 72
  START_HOUR = 6
  END_HOUR = 23
  MODES = [ [ "day", "Today" ], [ "3day", "3 Day" ], [ "week", "Week" ], [ "month", "Month" ] ].freeze
  # The phone (plan: Small screens; the approved mockup): agenda by default, one-column Day, Month.
  PHONE_MODES = [ [ "agenda", "Agenda" ], [ "day", "Day" ], [ "month", "Month" ] ].freeze

  def calendar_modes
    frame_layout? ? MODES : PHONE_MODES
  end

  # Links that keep the person filter (phone chips) across modes, days and taps.
  def calendar_url(mode, date, person)
    calendar_path(mode: mode, date: date, person: person&.id)
  end

  def grid_height
    (END_HOUR - START_HOUR) * PX
  end

  # Pixels from the top of the grid for a time.
  def grid_y(t)
    ((t.hour + t.min / 60.0) - START_HOUR) * PX
  end

  # Top and height of an event clamped to the day's visible hours.
  def grid_box(event, day)
    day_start = day.in_time_zone.beginning_of_day
    from = event.starts_at < day_start ? day_start + START_HOUR.hours : event.starts_at
    end_of_day = day_start + END_HOUR.hours
    to = event.ends_at > end_of_day ? end_of_day : event.ends_at
    top = [ 0, grid_y(from) ].max
    [ top, [ 24, grid_y(to) - top - 3 ].max ]
  end

  def px(n)
    "#{format('%g', n.round(2))}px"
  end

  def hour_label(h)
    return "Noon" if h == 12
    "#{h % 12 == 0 ? 12 : h % 12} #{h < 12 ? 'AM' : 'PM'}"
  end

  def now_in_grid?(now)
    now.hour >= START_HOUR && now.hour < END_HOUR
  end

  def calendar_title(mode, date, now)
    case mode
    when "day", "agenda"
      { kicker: "#{fmt_month(date)} #{date.year} · #{fmt_rel(date, now: now)}", title: safe_join([ fmt_day(date), " ", tag.i(date.day) ]) }
    when "3day"
      e = date + 2
      { kicker: "#{fmt_month(date)} #{date.year}", title: safe_join([ "#{fmt_day_short(date)} #{date.day} ", tag.i("–"), " #{fmt_day_short(e)} #{e.day}" ]) }
    when "week"
      w = date + 6
      { kicker: "Next 7 days", title: safe_join([ "#{fmt_month_short(date)} #{date.day} ", tag.i("–"), " #{fmt_month_short(w)} #{w.day}" ]) }
    else
      { kicker: date.year.to_s, title: fmt_month(date) }
    end
  end

  def calendar_nav_date(mode, date, dir)
    case mode
    when "month" then (date >> dir).beginning_of_month
    when "day", "agenda" then date + dir
    when "3day" then date + 3 * dir
    else date + 7 * dir
    end
  end

  def calendar_is_today?(mode, date, now)
    mode == "month" ? date.month == now.month && date.year == now.year : date == now.to_date
  end
end
