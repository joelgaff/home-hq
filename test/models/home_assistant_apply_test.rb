require "test_helper"

# Writes through the hub (plan: milestone 5; ui-spec §1.6 optimistic contract): a mapped device's
# apply calls the matching service and lands the patch, or refuses it when the hub cannot be
# reached; unmapped devices keep the mock bridge's behaviour.
class HomeAssistantApplyTest < ActiveSupport::TestCase
  setup do
    @household = households(:primary)
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    @calls = []
    HomeAssistant.transport = ->(request) { @calls << [ request[:path], request[:body] ]; [ 200, {} ] }
    @light = devices(:island)
    @light.update!(entity_id: "light.island")
  end

  teardown { HomeAssistant.reset! }

  def calls = @calls.map { |path, body| [ path.sub("/api/services/", ""), body ] }

  test "a light's on, level and off become light.turn_on / turn_off; a switch has no brightness" do
    assert @light.apply(on: true, level: 40)
    assert_equal [ [ "light/turn_on", { "entity_id" => "light.island", "brightness_pct" => 40 } ] ], calls
    assert_equal [ true, 40 ], [ @light.reload.on?, @light.level ]
    assert @light.apply(on: false)
    assert_equal [ "light/turn_off", { "entity_id" => "light.island" } ], calls.last
    assert_not @light.reload.on?

    @light.update!(entity_id: "switch.porch")
    @light.apply(on: true, level: 100)
    assert_equal [ "switch/turn_on", { "entity_id" => "switch.porch" } ], calls.last
  end

  test "locks, blinds and garage doors call their domains" do
    lock = devices(:front_door)
    lock.update!(entity_id: "lock.front")
    assert lock.apply(locked: false)
    assert_equal [ "lock/unlock", { "entity_id" => "lock.front" } ], calls.last
    assert_not lock.reload.locked?
    lock.apply(locked: true)
    assert_equal "lock/lock", calls.last.first

    blind = devices(:shade)
    blind.update!(entity_id: "cover.living")
    blind.apply(position: 30)
    assert_equal [ "cover/set_cover_position", { "entity_id" => "cover.living", "position" => 30 } ], calls.last
    assert_equal 30, blind.reload.position

    garage = devices(:garage)
    garage.update!(entity_id: "cover.garage")
    garage.apply(state: "opening")
    assert_equal [ "cover/open_cover", { "entity_id" => "cover.garage" } ], calls.last
    garage.apply(state: "closing")
    assert_equal "cover/close_cover", calls.last.first
  end

  test "the thermostat sets its temperature in the hub's unit and its mode; the speaker toggles play" do
    @household.update!(temperature_unit: "f")
    thermostat = @household.thermostat
    thermostat.update!(entity_id: "climate.ecobee", target_temperature: 70, current_temperature: 68)
    HomeAssistant.transport = lambda do |request|
      @calls << [ request[:path], request[:body] ]
      request[:path] == "/api/config" ? [ 200, { "unit_system" => { "temperature" => "°C" } } ] : [ 200, {} ]
    end
    thermostat.adjust!(1)
    assert_equal [ "climate/set_temperature", { "entity_id" => "climate.ecobee", "temperature" => 21.7 } ], calls.last
    assert_equal 71, thermostat.reload.target_temperature
    thermostat.set_mode!("cool")
    assert_equal [ "climate/set_hvac_mode", { "entity_id" => "climate.ecobee", "hvac_mode" => "cool" } ], calls.last

    player = @household.media_player
    player.update!(entity_id: "media_player.kitchen", playing: true)
    player.toggle!
    assert_equal [ "media_player/media_pause", { "entity_id" => "media_player.kitchen" } ], calls.last
    assert_not player.reload.playing?
    player.toggle!
    assert_equal "media_player/media_play", calls.last.first
  end

  test "a scene turns its hub scene on as well as setting its devices" do
    scene = scenes(:movie)
    scene.update!(entity_id: "scene.movie")
    scene.scene_settings.find_or_initialize_by(device: @light).update!(level: 0)
    scene.activate!
    assert_includes calls.map(&:first), "scene/turn_on"
    assert_includes calls.map(&:first), "light/turn_off"
  end

  test "when the hub refuses or is unreachable the patch is refused and nothing changes" do
    @light.deviceable.update!(on: true)
    HomeAssistant.transport = ->(_r) { [ 500, { "message" => "boom" } ] }
    assert_not @light.apply(on: false)
    assert @light.reload.on?
    HomeAssistant.transport = ->(_r) { raise Errno::ECONNREFUSED }
    assert_not @light.apply(on: false)
    assert @light.reload.on?
  end

  test "unmapped devices never call the hub and keep the mock behaviour" do
    @light.update!(entity_id: nil)
    assert @light.apply(on: false)
    assert_empty @calls
    assert_not devices(:string_lights).apply(on: true)
  end
end
