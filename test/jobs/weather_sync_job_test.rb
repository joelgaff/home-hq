require "test_helper"
require "turbo/broadcastable/test_helper"

# Weather from Home Assistant's weather entity (plan: Integrations: every 30 min; conditions mapped
# to Wes's five). The report is in the household's unit; the Today weather piece is told.
class WeatherSyncJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @household.update!(weather_entity: "weather.home", temperature_unit: "f")
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    HomeAssistant.transport = lambda do |request|
      case request[:path]
      when "/api/states/weather.home"
        [ 200, { "state" => "partlycloudy", "attributes" => { "temperature" => 16, "temperature_unit" => "°C" } } ]
      when "/api/services/weather/get_forecasts"
        if request[:body]["type"] == "hourly"
          forecast = (0..30).map do |i|
            t = Time.utc(2026, 10, 14, 15) + i.hours
            { "datetime" => t.iso8601, "temperature" => 16 - i, "condition" => (i >= 3 ? "rainy" : "sunny"), "precipitation_probability" => (i >= 3 ? 80 : 10) }
          end
          [ 200, { "service_response" => { "weather.home" => { "forecast" => forecast } } } ]
        else
          [ 200, { "service_response" => { "weather.home" => { "forecast" => [ { "datetime" => "2026-10-14T00:00:00+00:00", "temperature" => 18, "templow" => 7, "condition" => "rainy" } ] } } } ]
        end
      end
    end
  end

  teardown { HomeAssistant.reset! }

  test "a report for today in the household's unit, hourly from now, mapped conditions, told to the screens" do
    streams = capture_turbo_stream_broadcasts(@household) { WeatherSyncJob.perform_now }
    assert_equal [ "today-weather" ], streams.map { |s| s["targets"] }
    report = @household.latest_weather
    assert_equal [ 64, 45, "weather.home" ], [ report.high, report.low, report.source ]  # 18 °C / 7 °C
    now = report.hourly_forecasts.find_by(hour: 15)
    assert_equal [ 61, "sun", 10 ], [ now.temperature, now.condition, now.precipitation_chance ]
    assert_equal "rain", report.hourly_forecasts.find_by(hour: 18).condition
    assert_equal 24, report.hourly_forecasts.count, "every hour of today has a cell"
    assert_equal "Rain from 6 PM", report.outlook.summary
  end

  test "syncing again replaces today's report instead of piling up" do
    WeatherSyncJob.perform_now
    WeatherSyncJob.perform_now
    assert_equal 1, @household.weather_reports.where(source: "weather.home").count
  end

  test "nothing happens without Home Assistant or without an entity, and the demo report stays" do
    HomeAssistant.reset!
    assert_empty capture_turbo_stream_broadcasts(@household) { WeatherSyncJob.perform_now }
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    @household.update!(weather_entity: nil)
    WeatherSyncJob.perform_now
    assert_equal 0, @household.weather_reports.where.not(source: nil).count
  end

  test "the job is on the schedule every 30 minutes" do
    entry = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]["weather_sync"]
    assert_equal "WeatherSyncJob", entry["class"]
    assert_match(/30 minutes/, entry["schedule"])
  end
end
