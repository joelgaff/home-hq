require "test_helper"

# Weather without Home Assistant (owner, 2026-10-19): a place typed in Settings is looked up with
# Open-Meteo's geocoder (free, no key), and the weather job reads Open-Meteo's forecast for it.
class OpenMeteoWeatherTest < ActiveJob::TestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @household.update!(weather_entity: "", temperature_unit: "f", time_zone: "America/New_York")
    @requests = []
    OpenMeteo.transport = lambda do |url|
      @requests << url
      case url
      when /geocoding-api/
        url.include?("Nowhere") ? [ 200, { "generationtime_ms" => 0.1 } ] : [ 200, { "results" => [ { "name" => "Asheville", "admin1" => "North Carolina", "country_code" => "US", "latitude" => 35.6, "longitude" => -82.55 } ] } ]
      when /api\.open-meteo\.com/
        hours = (0..23).map { |h| "2026-10-14T%02d:00" % h }
        [ 200, { "hourly" => { "time" => hours, "temperature_2m" => (0..23).map { |h| 50 + h }, "weather_code" => (0..23).map { |h| h < 16 ? 0 : 61 },
                               "precipitation_probability" => (0..23).map { |h| h < 16 ? 5 : 70 }, "is_day" => (0..23).map { |h| h.between?(7, 18) ? 1 : 0 } },
                 "daily" => { "time" => [ "2026-10-14" ], "temperature_2m_max" => [ 72.4 ], "temperature_2m_min" => [ 48.6 ] } } ]
      end
    end
  end

  teardown { OpenMeteo.reset! }

  test "a weather location is looked up when saved; an unknown place is refused" do
    @household.update!(weather_location: "Asheville")
    assert_equal [ "Asheville, North Carolina, US", 35.6, -82.55 ], [ @household.weather_location, @household.weather_latitude.to_f, @household.weather_longitude.to_f ]
    assert_not @household.update(weather_location: "Nowhere")
    assert_match(/couldn.t find/i, @household.errors[:weather_location].join)
    @household.reload.update!(weather_location: "")
    assert_nil @household.weather_latitude
  end

  test "the job reads Open-Meteo for a household with a location and no hub weather" do
    @household.update!(weather_location: "Asheville")
    WeatherSyncJob.perform_now
    report = @household.latest_weather
    assert_equal [ 72, 49, "open_meteo" ], [ report.high, report.low, report.source ]
    assert_equal [ 65, "sun", 5 ], report.hourly_forecasts.find_by(hour: 15).slice(:temperature, :condition, :precipitation_chance).values
    assert_equal "rain", report.hourly_forecasts.find_by(hour: 17).condition
    assert_equal "moon", report.hourly_forecasts.find_by(hour: 2).condition
    assert_match(/latitude=35.6.*temperature_unit=fahrenheit.*timezone=America%2FNew_York/, @requests.last)
  end

  test "a hub weather entity still wins when one is set" do
    @household.update!(weather_location: "Asheville", weather_entity: "weather.home")
    WeatherSyncJob.perform_now
    assert_not @requests.any? { |u| u.include?("//api.open-meteo.com") }
  end
end
