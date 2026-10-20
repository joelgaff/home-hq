require "test_helper"

# Settings → Integrations (plan: Integrations; Our instance: every one optional): the Home
# Assistant status, the weather entity, the home address and region for travel times.
class SettingsIntegrationsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }
  teardown { HomeAssistant.reset! }

  test "the household form takes the weather entity, home address and travel region, and shows the hub's status" do
    get settings_path
    assert_select "p", text: /Home Assistant is not connected/i
    assert_select "input[name='household[weather_entity]']", 1
    assert_select "input[name='household[home_address]']", 1
    assert_select "select[name='household[travel_region]'] option[value=us]", 1

    patch settings_path, params: { household: { weather_entity: "weather.home", home_address: "1 Main St, Springfield", travel_region: "eu" } }
    assert_redirected_to settings_path
    h = households(:primary).reload
    assert_equal [ "weather.home", "1 Main St, Springfield", "eu" ], [ h.weather_entity, h.home_address, h.travel_region ]

    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    get settings_path
    assert_select "p", text: /Home Assistant is connected/i
  end

  test "a made-up region is refused" do
    patch settings_path, params: { household: { travel_region: "mars" } }
    assert_response :unprocessable_entity
  end

  test "a weather location is typed in, looked up, and fetched right away" do
    OpenMeteo.transport = ->(_url) { [ 200, { "results" => [ { "name" => "Asheville", "admin1" => "North Carolina", "country_code" => "US", "latitude" => 35.6, "longitude" => -82.55 } ] } ] }
    get settings_path
    assert_select "input[name='household[weather_location]']", 1
    assert_select "input[name='household[rain_keywords]'][value*=soccer]", 1
    assert_enqueued_with(job: WeatherSyncJob) do
      patch settings_path, params: { household: { weather_location: "Asheville" } }
    end
    assert_redirected_to settings_path
    assert_equal "Asheville, North Carolina, US", households(:primary).reload.weather_location
  ensure
    OpenMeteo.reset!
  end
end
