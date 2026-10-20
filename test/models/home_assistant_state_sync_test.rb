require "test_helper"
require "turbo/broadcastable/test_helper"

# Hub states → our rows (plan: milestone 5): a state_changed event for a mapped entity updates
# the device, thermostat, speaker or person, and the screens hear about it; a full refresh does
# the same for every state at once.
class HomeAssistantStateSyncTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @household = households(:primary)
    @light = devices(:island)
    @light.update!(entity_id: "light.island")
    @light.deviceable.update!(on: false, level: 100)
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    HomeAssistant.transport = ->(_r) { [ 200, {} ] }
    HomeAssistant::StateSync.forget_unit!
  end

  teardown { HomeAssistant.reset! }

  test "a light, lock, blind, garage, climate, media player and person follow their entity's state" do
    devices(:front_door).update!(entity_id: "lock.front")
    devices(:shade).update!(entity_id: "cover.living")
    devices(:garage).update!(entity_id: "cover.garage")
    @household.thermostat.update!(entity_id: "climate.ecobee")
    @household.media_player.update!(entity_id: "media_player.kitchen", playing: false)
    people(:wes).update!(presence_entity: "person.wes", home: false, status: "Driving home", eta_minutes: 12)

    streams = capture_turbo_stream_broadcasts(@household) do
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "light.island", "state" => "on", "attributes" => { "brightness" => 64 } })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "lock.front", "state" => "unlocked", "attributes" => {} })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "cover.living", "state" => "open", "attributes" => { "current_position" => 45 } })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "cover.garage", "state" => "opening", "attributes" => { "device_class" => "garage" } })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "climate.ecobee", "state" => "cool", "attributes" => { "current_temperature" => 23, "temperature" => 22, "current_humidity" => 51 } })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "media_player.kitchen", "state" => "playing", "attributes" => { "media_title" => "Harvest", "media_artist" => "Neil Young" } })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "person.wes", "state" => "home", "attributes" => {} })
      HomeAssistant::StateSync.apply(@household, { "entity_id" => "light.unknown", "state" => "on", "attributes" => {} })
    end
    assert_equal [ true, 25 ], [ @light.reload.on?, @light.level ]
    assert_not devices(:front_door).reload.locked?
    assert_equal 45, devices(:shade).reload.position
    assert_equal "opening", devices(:garage).reload.state
    t = @household.thermostat.reload
    assert_equal [ 23, 22, 51, "cool" ], [ t.current_temperature, t.target_temperature, t.humidity, t.mode ]
    p = @household.media_player.reload
    assert_equal [ true, "Harvest", "Neil Young" ], [ p.playing?, p.title, p.artist ]
    w = people(:wes).reload
    assert_equal [ true, "Home", nil ], [ w.home?, w.status, w.eta_minutes ]
    assert streams.any?, "the screens hear about it"
  end

  test "a person away is away, in a zone by its name" do
    people(:wes).update!(presence_entity: "person.wes", home: true, status: "Home")
    HomeAssistant::StateSync.apply(@household, { "entity_id" => "person.wes", "state" => "not_home", "attributes" => {} })
    assert_equal [ false, "Away" ], [ people(:wes).reload.home?, people(:wes).status ]
    HomeAssistant::StateSync.apply(@household, { "entity_id" => "person.wes", "state" => "Office", "attributes" => {} })
    assert_equal "At Office", people(:wes).reload.status
  end

  test "a full refresh reads every state once, and the refresh job runs it on the schedule" do
    HomeAssistant.transport = lambda do |request|
      request[:path] == "/api/states" ? [ 200, [ { "entity_id" => "light.island", "state" => "on", "attributes" => { "brightness" => 255 } } ] ] : [ 200, {} ]
    end
    HomeAssistant::StateSync.refresh(@household)
    assert_equal [ true, 100 ], [ @light.reload.on?, @light.level ]

    @light.deviceable.update!(on: false)
    HomeStateRefreshJob.perform_now
    assert @light.reload.on?
    entry = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]["home_state_refresh"]
    assert_equal "HomeStateRefreshJob", entry["class"]
  end

  test "unavailable and unknown states leave the row alone" do
    @light.deviceable.update!(on: true, level: 70)
    HomeAssistant::StateSync.apply(@household, { "entity_id" => "light.island", "state" => "unavailable", "attributes" => {} })
    assert_equal [ true, 70 ], [ @light.reload.on?, @light.level ]
  end
end
