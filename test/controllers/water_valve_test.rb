require "test_helper"

# The leak takeover's "hold to shut off water" (ui-spec §1.9; plan: milestone 6): closes the
# household's water valve through the hub when one is mapped, and is logged.
class WaterValveTest < ActionDispatch::IntegrationTest
  setup do
    show_on_screen(name: "Kitchen")
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    @calls = []
    HomeAssistant.transport = ->(request) { @calls << request[:path]; [ 200, {} ] }
  end

  teardown { HomeAssistant.reset! }

  test "closing the valve calls the hub's valve or switch and is logged; no valve means nothing to close" do
    post close_water_valve_path, as: :turbo_stream
    assert_response :not_found

    households(:primary).update!(water_valve_entity: "valve.water_main")
    post close_water_valve_path, as: :turbo_stream
    assert_response :no_content
    assert_equal [ "/api/services/valve/close_valve" ], @calls
    assert_equal [ "valve.closed", "Kitchen" ], [ households(:primary).audit_entries.last.action, households(:primary).audit_entries.last.actor_name ]

    households(:primary).update!(water_valve_entity: "switch.water_main")
    post close_water_valve_path, as: :turbo_stream
    assert_equal "/api/services/switch/turn_off", @calls.last

    HomeAssistant.transport = ->(_r) { raise Errno::ECONNREFUSED }
    post close_water_valve_path, as: :turbo_stream
    assert_response :service_unavailable
  end

  test "the valve entity is set under Settings → Integrations" do
    reset!
    sign_in_as users(:owner)
    get settings_path
    assert_select "input[name='household[water_valve_entity]']", 1
    patch settings_path, params: { household: { water_valve_entity: "valve.water_main" } }
    assert_equal "valve.water_main", households(:primary).reload.water_valve_entity
  end
end
