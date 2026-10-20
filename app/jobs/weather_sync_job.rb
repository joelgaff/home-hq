# Weather from each household's Home Assistant weather entity (plan: Integrations: every 30 min):
# the current state plus the hourly and daily forecasts become today's WeatherReport in the
# household's unit, with Home Assistant's conditions mapped to Wes's five (ui-spec §1.1).
class WeatherSyncJob < ApplicationJob
  queue_as :default

  CONDITIONS = {
    "sunny" => "sun", "clear-night" => "moon", "partlycloudy" => "partly", "windy" => "partly", "windy-variant" => "partly",
    "cloudy" => "cloud", "fog" => "cloud", "snowy" => "cloud", "exceptional" => "cloud",
    "rainy" => "rain", "pouring" => "rain", "lightning" => "rain", "lightning-rainy" => "rain", "snowy-rainy" => "rain", "hail" => "rain"
  }.freeze

  # Open-Meteo's WMO weather codes, in Wes's five (clear at night is the moon).
  WMO = ->(code, day) do
    case code.to_i
    when 0 then day ? "sun" : "moon"
    when 1, 2 then day ? "partly" : "moon"
    when 51..67, 80..82, 95..99 then "rain"
    else "cloud"
    end
  end

  def perform
    Household.find_each do |household|
      hub = household.weather_entity.present? && HomeAssistant.configured?
      next unless hub || (household.weather_entity.blank? && household.weather_located?)
      Current.household = household
      Time.use_zone(household.time_zone) { hub ? sync(household) : sync_open_meteo(household) }
    rescue *(HomeAssistant::FAILURES + OpenMeteo::FAILURES) => e
      Rails.logger.warn "Weather sync for #{household.name} failed: #{e.message}"
    ensure
      Current.household = nil
    end
  end

  private

  # Open-Meteo answers in the household's unit and zone already.
  def sync_open_meteo(household)
    data = OpenMeteo.forecast(latitude: household.weather_latitude, longitude: household.weather_longitude,
                              unit: household.temperature_unit, zone: household.time_zone)
    hourly = data["hourly"] || {}
    today = Time.current.to_date
    cells = Array(hourly["time"]).each_with_index.filter_map do |t, i|
      at = Time.zone.parse(t.to_s)
      next unless at&.to_date == today
      [ at.hour, { temperature: hourly["temperature_2m"][i].to_f.round, condition: WMO.(hourly["weather_code"][i], hourly["is_day"]&.dig(i).to_i == 1),
                   precipitation_chance: hourly["precipitation_probability"]&.dig(i).to_i } ]
    end.to_h
    return if cells.empty?
    daily = data["daily"] || {}
    high = daily["temperature_2m_max"]&.first || cells.values.map { |c| c[:temperature] }.max
    low = daily["temperature_2m_min"]&.first || cells.values.map { |c| c[:temperature] }.min
    household.transaction do
      household.weather_reports.where(source: "open_meteo").destroy_all
      report = household.weather_reports.create!(source: "open_meteo", fetched_at: Time.current, high: high.to_f.round, low: low.to_f.round)
      24.times { |hour| report.hourly_forecasts.create!(hour: hour, **(cells[hour] || cells.values.last)) }
    end
  end

  def sync(household)
    entity = household.weather_entity
    state = HomeAssistant.state(entity)
    hourly = forecast(entity, "hourly")
    daily = forecast(entity, "daily")
    unit = state.dig("attributes", "temperature_unit").to_s
    now = Time.current
    today = now.to_date
    convert = ->(t) { household.convert_temperature(t, from: unit) }

    by_hour = hourly.each_with_object({}) do |f, h|
      t = Time.zone.parse(f["datetime"].to_s)
      h[t.hour] ||= f if t && t.to_date == today
    end
    previous = household.latest_weather&.hourly_forecasts&.index_by(&:hour) || {}
    day = daily.find { |f| Time.zone.parse(f["datetime"].to_s)&.to_date == today } || daily.first || {}
    temps = by_hour.values.map { |f| f["temperature"] }.compact
    high = day["temperature"] || temps.max || state.dig("attributes", "temperature")
    low = day["templow"] || temps.min || state.dig("attributes", "temperature")

    household.transaction do
      household.weather_reports.where(source: entity).destroy_all
      report = household.weather_reports.create!(source: entity, fetched_at: now, high: convert.(high), low: convert.(low))
      24.times do |hour|
        f = by_hour[hour]
        cell = if f
          { temperature: convert.(f["temperature"]), condition: CONDITIONS.fetch(f["condition"].to_s, "cloud"), precipitation_chance: f["precipitation_probability"].to_i }
        elsif hour == now.hour
          { temperature: convert.(state.dig("attributes", "temperature")), condition: CONDITIONS.fetch(state["state"].to_s, "cloud"), precipitation_chance: 0 }
        elsif previous[hour]
          previous[hour].slice(:temperature, :condition, :precipitation_chance)
        else
          { temperature: convert.(state.dig("attributes", "temperature")), condition: CONDITIONS.fetch(state["state"].to_s, "cloud"), precipitation_chance: 0 }
        end
        report.hourly_forecasts.create!(hour: hour, **cell)
      end
    end
  end

  def forecast(entity, type)
    HomeAssistant.call("weather", "get_forecasts", { entity_id: entity, type: type }).dig("service_response", entity, "forecast") || []
  end
end
