# One day's forecast (hourly temperature, condition, chance of rain, plus high/low). Fetched from
# Home Assistant or Open-Meteo (WeatherSyncJob); seeded for the demo. The copy rules are Wes's
# (ui-spec §1.1).
class WeatherReport < ApplicationRecord
  include SyncsPieces

  CONDITION_LABELS = { "sun" => "Sunny", "moon" => "Clear", "partly" => "Partly cloudy", "cloud" => "Overcast", "rain" => "Rain" }.freeze
  WET_AT = 50 # % chance of rain

  belongs_to :household
  has_many :hourly_forecasts, -> { order(:hour) }, dependent: :destroy

  validates :high, :low, presence: true
  syncs_pieces :"today-weather"

  Outlook = Struct.new(:temperature, :condition, :label, :high, :low, :summary, :advice, :hour, keyword_init: true)
  Cell = Struct.new(:hour, :temperature, :condition, :precipitation_chance, :label, keyword_init: true) do
    def wet? = precipitation_chance >= WET_AT
  end

  STALE_AFTER = 90.minutes

  # A report from a live source that has not been refreshed for a while (the demo's never is).
  def stale?(now = Current.now)
    source.present? && (fetched_at.nil? || fetched_at < now - STALE_AFTER)
  end

  def outlook(at: Current.now)
    hour = at.hour
    hours = hourly_forecasts.index_by(&:hour)
    rain_at = (hour..23).find { |h| hours[h].precipitation_chance >= WET_AT }
    if rain_at == hour
      stop = hour
      stop += 1 while stop < 24 && hours[stop]&.precipitation_chance.to_i >= WET_AT
      summary, advice = "Rain until #{hour_label(stop)}", "Umbrella weather"
    elsif rain_at
      outing = outdoor_word_ahead(at)
      summary, advice = "Rain from #{hour_label(rain_at)}", (outing ? "Pack a rain jacket for #{outing}" : "Grab a rain jacket")
    elsif hours[hour].temperature < household.cool_below
      summary, advice = "Clear and cool", "Jacket weather"
    else
      summary, advice = "Dry all day", "Light layers"
    end
    now = hours[hour]
    Outlook.new(temperature: now.temperature, condition: now.condition, label: CONDITION_LABELS[now.condition],
      high: high, low: low, summary: summary, advice: advice, hour: hour)
  end

  # `count` hourly cells starting now ("Now", "4p", "5p"...), wrapping past midnight.
  def hourly(at: Current.now, count: 7)
    hours = hourly_forecasts.index_by(&:hour)
    count.times.map do |i|
      h = (at.hour + i) % 24
      f = hours[h]
      Cell.new(hour: h, temperature: f.temperature, condition: f.condition, precipitation_chance: f.precipitation_chance,
        label: i.zero? ? "Now" : "#{h % 12 == 0 ? 12 : h % 12}#{h >= 12 ? 'p' : 'a'}")
    end
  end

  private

  # The first of the household's outdoor words found in an event still ahead today.
  def outdoor_word_ahead(at)
    words = household.rain_keywords.to_s.split(",").map(&:strip).compact_blank
    return nil if words.empty?
    titles = household.timed_events_on(at).select { |e| e.starts_at > at }.map(&:title)
    words.find { |w| titles.any? { |t| t.match?(/\b#{Regexp.escape(w)}\b/i) } }&.downcase
  end

  def hour_label(h)
    h %= 24
    "#{h % 12 == 0 ? 12 : h % 12} #{h >= 12 ? 'PM' : 'AM'}"
  end
end
