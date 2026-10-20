# Wes's time copy (app.js App.fmt), for Times already in the household's zone, in the household's
# clock format (12-hour with AM/PM, or 24-hour; plan: Our instance).
module TimeFormatHelper
  def clock_24?
    Current.household&.clock_24? || false
  end

  # "3:45 PM" / "3:45"; "15:45" on a 24-hour clock
  def fmt_time(t, ampm: true)
    return t.strftime("%H:%M") if clock_24?
    ampm ? t.strftime("%-l:%M %p") : t.strftime("%-l:%M")
  end

  def fmt_ampm(t)
    clock_24? ? "" : t.strftime("%p")
  end

  # "4 PM", "3:45 PM"; "16:00" on a 24-hour clock
  def fmt_hour(t)
    return t.strftime("%H:%M") if clock_24?
    t.min.zero? ? t.strftime("%-l %p") : t.strftime("%-l:%M %p")
  end

  # "3:45 – 4:30 PM", "11:30 AM – 1:00 PM"; "15:45 – 16:30"
  def fmt_range(a, b)
    same = clock_24? || fmt_ampm(a) == fmt_ampm(b)
    "#{fmt_time(a, ampm: !same)} – #{fmt_time(b)}"
  end

  # "12 min", "1 hr 5 min"
  def fmt_mins(minutes)
    m = [ 0, minutes.round ].max
    return "#{m} min" if m < 60
    h, r = m.divmod(60)
    r.zero? ? "#{h} hr" : "#{h} hr #{r} min"
  end

  # "Today", "Tomorrow", "Yesterday", else the weekday
  def fmt_rel(t, now: Current.now)
    diff = (t.to_date - now.to_date).to_i
    { 0 => "Today", 1 => "Tomorrow", -1 => "Yesterday" }[diff] || t.strftime("%A")
  end

  def fmt_day(t) = t.strftime("%A")
  def fmt_day_short(t) = t.strftime("%a")
  def fmt_month(t) = t.strftime("%B")

  MONTH_SHORT = %w[Jan Feb Mar Apr May June July Aug Sept Oct Nov Dec].freeze
  def fmt_month_short(t) = MONTH_SHORT[t.month - 1]

  # Epoch milliseconds for the browser's local countdowns.
  def ms(t)
    (t.to_f * 1000).round
  end
end
