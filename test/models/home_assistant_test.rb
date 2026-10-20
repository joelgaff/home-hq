require "test_helper"

# The Home Assistant client (plan: Simplifications 2, Integrations): the hub for weather, travel
# and, from milestone 5, the house. Off until a URL and token are set; tests hand in a transport.
class HomeAssistantTest < ActiveSupport::TestCase
  teardown { HomeAssistant.reset! }

  test "off until configured; then it reads states and calls services with the token" do
    assert_not HomeAssistant.configured?
    HomeAssistant.configure(url: "http://ha.test:8123", token: "secret-token")
    assert HomeAssistant.configured?

    calls = []
    HomeAssistant.transport = lambda do |request|
      calls << request
      case request[:path]
      when "/api/states/weather.home" then [ 200, { "state" => "sunny", "attributes" => { "temperature" => 21.4 } } ]
      when "/api/services/weather/get_forecasts" then [ 200, { "service_response" => { "weather.home" => { "forecast" => [] } } } ]
      end
    end
    state = HomeAssistant.state("weather.home")
    assert_equal [ "sunny", 21.4 ], [ state["state"], state.dig("attributes", "temperature") ]
    response = HomeAssistant.call("weather", "get_forecasts", { entity_id: "weather.home", type: "hourly" })
    assert_equal [], response.dig("service_response", "weather.home", "forecast")

    assert_equal [ "GET", "http://ha.test:8123/api/states/weather.home", "Bearer secret-token" ], [ calls[0][:method], calls[0][:url], calls[0][:headers]["Authorization"] ]
    assert_equal [ "POST", "http://ha.test:8123/api/services/weather/get_forecasts?return_response", { "entity_id" => "weather.home", "type" => "hourly" } ],
      [ calls[1][:method], calls[1][:url], calls[1][:body] ]
  end

  test "an error answer raises, and nothing is called when off" do
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    HomeAssistant.transport = ->(_r) { [ 401, { "message" => "Unauthorized" } ] }
    assert_raises(HomeAssistant::Error) { HomeAssistant.state("weather.home") }
    HomeAssistant.reset!
    HomeAssistant.transport = ->(_r) { flunk "no call when off" }
    assert_nil HomeAssistant.state("weather.home")
  end
end
