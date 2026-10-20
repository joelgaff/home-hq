require "test_helper"

# Settings → Home (plan: milestone 5): rooms, devices mapped to Home Assistant entities, scenes,
# climate, media and cameras; an import of what the hub knows; and clearing the demo home.
class SettingsHomeTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }
  teardown { HomeAssistant.reset! }

  def connect_hub
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    HomeAssistant.transport = lambda do |request|
      case request[:path]
      when "/api/states"
        [ 200, [
          { "entity_id" => "light.kitchen_island", "state" => "on", "attributes" => { "friendly_name" => "Kitchen Island", "brightness" => 128 } },
          { "entity_id" => "switch.porch", "state" => "off", "attributes" => { "friendly_name" => "Porch" } },
          { "entity_id" => "lock.front_door", "state" => "locked", "attributes" => { "friendly_name" => "Front Door" } },
          { "entity_id" => "cover.garage", "state" => "closed", "attributes" => { "friendly_name" => "Garage", "device_class" => "garage" } },
          { "entity_id" => "cover.den_blind", "state" => "open", "attributes" => { "friendly_name" => "Den Blind", "current_position" => 100 } },
          { "entity_id" => "climate.ecobee", "state" => "heat", "attributes" => { "friendly_name" => "Ecobee", "current_temperature" => 20.5, "temperature" => 21.5 } },
          { "entity_id" => "media_player.kitchen_speaker", "state" => "playing", "attributes" => { "friendly_name" => "Kitchen Speaker" } },
          { "entity_id" => "camera.doorbell", "state" => "idle", "attributes" => { "friendly_name" => "Doorbell" } },
          { "entity_id" => "person.joel", "state" => "home", "attributes" => { "friendly_name" => "Joel" } },
          { "entity_id" => "sensor.noise", "state" => "1", "attributes" => {} }
        ] ]
      else
        [ 200, {} ]
      end
    end
  end

  test "the Home page lists rooms with their devices, scenes, climate, media and cameras, and links from Settings" do
    get settings_path
    assert_select "a[href=?]", settings_home_path
    get settings_home_path
    assert_response :success
    assert_select "h2", text: /Rooms/
    assert_select "li", text: /Kitchen/
    assert_select "li", text: /Island.*light/mi
    assert_select "h2", text: /Scenes/
    assert_select "li", text: /Goodnight/
    assert_select "h2", text: /Climate/
    assert_select "h2", text: /Cameras/
    assert_select "p", text: /not connected/i
  end

  test "rooms and devices: add a device mapped to an entity, move it to a room, rename the room, remove both" do
    post settings_rooms_path, params: { room: { name: "Den" } }
    den = households(:primary).rooms.find_by!(name: "Den")
    post settings_devices_path, params: { device: { name: "Den lamp", kind: "Light", room_id: den.id, entity_id: "light.den_lamp" } }
    assert_redirected_to settings_home_path
    lamp = households(:primary).devices.find_by!(name: "Den lamp")
    assert_equal [ "Light", "light.den_lamp", den, false ], [ lamp.deviceable_type, lamp.entity_id, lamp.room, lamp.flaky? ]

    patch settings_device_path(lamp), params: { device: { name: "Reading lamp", room_id: rooms(:kitchen).id, entity_id: "" } }
    lamp.reload
    assert_equal [ "Reading lamp", rooms(:kitchen), nil ], [ lamp.name, lamp.room, lamp.entity_id ]
    patch settings_room_path(den), params: { room: { name: "Study" } }
    assert_equal "Study", den.reload.name

    patch move_settings_device_path(lamp), params: { direction: "up" }
    assert_redirected_to settings_home_path

    delete settings_device_path(lamp)
    assert_nil Device.find_by(id: lamp.id)
    assert_nil Light.find_by(id: lamp.deviceable_id), "the typed row goes with it"
    delete settings_room_path(den)
    assert_nil Room.find_by(id: den.id)
  end

  test "a device needs a known type and an entity may only be mapped once" do
    post settings_devices_path, params: { device: { name: "x", kind: "Toaster" } }
    assert_response :unprocessable_entity
    post settings_devices_path, params: { device: { name: "A", kind: "Light", entity_id: "light.same" } }
    post settings_devices_path, params: { device: { name: "B", kind: "Light", entity_id: "light.same" } }
    assert_response :unprocessable_entity
  end

  test "scenes: add one with device levels and lock-all, edit, remove" do
    island = devices(:island)
    post settings_scenes_path, params: { scene: { name: "Reading", icon: "book", locks_all: "1", levels: { island.id.to_s => "40" } } }
    scene = households(:primary).scenes.find_by!(name: "Reading")
    assert scene.locks_all?
    assert_equal({ island.id => 40 }, scene.scene_settings.to_h { |s| [ s.device_id, s.level ] })
    patch settings_scene_path(scene), params: { scene: { name: "Reading", locks_all: "0", levels: { island.id.to_s => "" } } }
    scene.reload
    assert_not scene.locks_all?
    assert_equal 0, scene.scene_settings.count, "a blank level drops the device from the scene"
    delete settings_scene_path(scene)
    assert_nil Scene.find_by(id: scene.id)
  end

  test "climate, media and cameras take their entities" do
    patch settings_climate_path, params: { thermostat: { entity_id: "climate.ecobee" } }
    assert_equal "climate.ecobee", households(:primary).thermostat.reload.entity_id
    patch settings_media_player_path, params: { media_player: { entity_id: "media_player.kitchen", room_id: rooms(:kitchen).id } }
    assert_equal "media_player.kitchen", households(:primary).media_player.reload.entity_id
    post settings_cameras_path, params: { camera: { name: "Drive", entity_id: "camera.drive" } }
    cam = households(:primary).cameras.find_by!(name: "Drive")
    assert_equal "camera.drive", cam.entity_id
    delete settings_camera_path(cam)
    assert_nil Camera.find_by(id: cam.id)
  end

  test "with the hub connected the forms offer its entities, and an import maps what is not mapped yet" do
    connect_hub
    get new_settings_device_path
    assert_select "datalist#entities option[value='light.kitchen_island']", 1
    assert_select "datalist#entities option[value='lock.front_door']", 1
    assert_select "datalist#entities option[value='sensor.noise']", 0

    post import_settings_home_path
    assert_redirected_to settings_home_path
    h = households(:primary)
    by_entity = h.devices.where.not(entity_id: nil).index_by(&:entity_id)
    assert_equal %w[Light Light DoorLock GarageDoor Blind], %w[light.kitchen_island switch.porch lock.front_door cover.garage cover.den_blind].map { |e| by_entity.fetch(e).deviceable_type }
    assert_equal "Kitchen Island", by_entity["light.kitchen_island"].name
    assert by_entity["light.kitchen_island"].on?
    assert_equal 50, by_entity["light.kitchen_island"].level
    assert_equal "climate.ecobee", h.thermostat.entity_id
    assert_equal "media_player.kitchen_speaker", h.media_player.entity_id
    assert_equal "camera.doorbell", h.cameras.find_by(name: "Doorbell").entity_id
    follow_redirect!
    assert_select ".page-flash", text: /5 devices/

    post import_settings_home_path
    assert_equal 1, h.devices.where(entity_id: "light.kitchen_island").count, "importing twice adds nothing"
  end

  test "clearing the home removes the demo rooms, devices, scenes, climate, media and cameras" do
    delete settings_home_path
    assert_redirected_to settings_home_path
    h = households(:primary).reload
    assert_equal [ 0, 0, 0, 0, nil, nil, 0 ], [ h.rooms.count, h.devices.count, h.scenes.count, h.scene_activations.count, h.thermostat, h.media_player, h.cameras.count ]
    assert_nil h.active_scene
    get root_path
    assert_response :success
    get control_path
    assert_response :success
  end
end
