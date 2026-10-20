require "test_helper"

# Presence (plan: Integrations; gap review: kids' presence hidden): the Today card shows the
# adults, each person can be tied to a hub person entity, and an adult away with a known position
# gets an ETA home from the Waze service.
class PresenceTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }
  teardown { HomeAssistant.reset! }

  test "the Today presence card shows adults only" do
    show_on_screen
    get root_path
    assert_select "#today-presence .h-who", 2
    assert_select "#today-presence .h-who b", text: "Wes"
    assert_select "#today-presence .h-who b", text: "Buzzsaw", count: 0
  end

  test "a person takes a presence entity, offered from the hub when connected" do
    sign_in_as users(:owner)
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    HomeAssistant.transport = ->(_r) { [ 200, [ { "entity_id" => "person.wes", "state" => "home", "attributes" => { "friendly_name" => "Wes" } } ] ] }
    get edit_settings_person_path(people(:wes))
    assert_select "input[name='person[presence_entity]'][list=entities]", 1
    assert_select "datalist#entities option[value='person.wes']", 1
    patch settings_person_path(people(:wes)), params: { person: { presence_entity: "person.wes" } }
    assert_equal "person.wes", people(:wes).reload.presence_entity
  end

  test "an adult away with a position gets an ETA home; at home it clears" do
    households(:primary).update!(home_address: "1 Home St")
    people(:wes).update!(presence_entity: "person.wes", home: false, status: "Away", presence_latitude: 43.65, presence_longitude: -79.38, eta_minutes: nil)
    people(:claudia).update!(presence_entity: "person.claudia", home: true, status: "Home", eta_minutes: 5)
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    calls = []
    HomeAssistant.transport = lambda do |request|
      calls << request[:body]
      [ 200, { "service_response" => { "routes" => [ { "duration" => 23.6 } ] } } ]
    end
    TravelSyncJob.perform_now
    assert_equal 24, people(:wes).reload.eta_minutes
    assert_equal({ "origin" => "43.65,-79.38", "destination" => "1 Home St" }, calls.last.slice("origin", "destination"))
    assert_nil people(:claudia).reload.eta_minutes
  end
end
