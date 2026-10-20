require "test_helper"

# The Home control view (docs/ui-spec.md §1.6).
class ControlControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  def tile(device) = "#device_#{device.id}"

  test "the dashboard page carries the control view" do
    get root_path
    assert_select "#view-control .hc .hc-left #control-sum", 1
    assert_select "#view-control .hc-right #control-climate", 1
  end

  test "summary cards: lights, security, climate, media" do
    get control_path
    assert_select "#control-sum .sum[data-sum=lights].sum--warm" do
      assert_select "b", "3"
      assert_select "small", "on in 3 rooms"
    end
    assert_select "#control-sum .sum[data-sum=security]:not(.sum--warn)" do
      assert_select "b", "Locked"
      assert_select "small", "All doors + garage"
    end
    assert_select "#control-sum .sum[data-sum=climate] b", "20.5°"
    assert_select "#control-sum .sum[data-sum=climate] small", "Heating to 21.5°"
    assert_select "#control-sum .sum[data-sum=media] b", "Playing"
    assert_select "#control-sum .sum[data-sum=media] small", "Kitchen speaker"
  end

  test "security summary when something is open" do
    devices(:side_door).apply(locked: false)
    devices(:garage).apply(state: "open")
    get control_path
    assert_select "#control-sum .sum[data-sum=security].sum--warn b", "2"
    assert_select "#control-sum .sum[data-sum=security] small", "Garage open · Side Door open"
  end

  test "scenes, rooms and tiles per device type" do
    get control_path
    assert_select "#control-scenes .scene", 2
    assert_select "#control-rooms .room", 4
    assert_select "#control-rooms .room:first-child .room-h h3", "Kitchen"
    assert_select "#control-rooms .room:first-child [data-room-count]", "1 on"
    assert_select "#{tile(devices(:pendants))}.tile--light.is-on[style*='--lvl:80%'] .tile-state", "80%"
    assert_select "#{tile(devices(:island))}.tile--light:not(.is-on) .tile-state", "Off"
    assert_select "#{tile(devices(:shade))}.tile--blind.is-on[style*='--lvl:60%'] .tile-state", "60% open"
    assert_select "#{tile(devices(:front_door))}.tile--lock:not(.is-warn) .tile-state", /Locked\s*Hold to unlock/
    assert_select "#{tile(devices(:front_door))} svg.hold-ring", 1
    assert_select "#{tile(devices(:garage))}.tile--garage .tile-state", "Closed"
  end

  test "climate panel, cameras and now playing" do
    get control_path
    assert_select "#control-climate .th-set .num", "21.5°"
    assert_select "#control-climate .th-now", /20\.5°\s*inside/
    assert_select "#control-climate .th-verb--heating", "Heating"
    assert_select "#control-climate .seg button.is-on[data-tmode=heat]", 1
    assert_select "#control-cams .cam", 2
    assert_select "#control-cams .cam[data-cam='#{cameras(:front).id}'] .cam-name", "Front Porch"
    assert_select "#control-media .np-text b", "Harvest Moon"
    assert_select "#control-media .np-btn[data-playing=true]", 1
  end

  test "a device patch lands and re-renders its tile, the room count, the summary and the Today card" do
    patch device_path(devices(:island)), params: { on: true, level: 70 }, as: :turbo_stream
    assert devices(:island).reload.on?
    assert_select "turbo-stream[action=replace][targets='.device-#{devices(:island).id}'] .tile.is-on .tile-state", "70%"
    assert_select "turbo-stream[action=replace][target=control-sum] .sum[data-sum=lights] b", "4"
    assert_select "turbo-stream[action=replace][target=room_#{rooms(:kitchen).id}_count]", "2 on"
    assert_select "turbo-stream[action=replace][target=today-status]", 1
    assert_select "turbo-stream[target=toasts] .toast", 0
  end

  test "an unreachable device is reverted with a red toast" do
    patch device_path(devices(:string_lights)), params: { on: true }, as: :turbo_stream
    assert_not devices(:string_lights).reload.on?
    assert_select "turbo-stream[targets='.device-#{devices(:string_lights).id}'] .tile:not(.is-on)", 1
    assert_select "turbo-stream[target=toasts] .toast.toast--error .toast-msg", /Couldn’t reach\s*String Lights\s*· it may be offline/
  end

  test "unlocking a door toasts; locking does not" do
    patch device_path(devices(:front_door)), params: { locked: false }, as: :turbo_stream
    assert_select "turbo-stream[target=toasts] .toast-msg", /Front Door\s*unlocked/
    assert_select "turbo-stream[target=control-sum] .sum[data-sum=security].sum--warn", 1
    patch device_path(devices(:front_door)), params: { locked: true }, as: :turbo_stream
    assert_select "turbo-stream[target=toasts] .toast", 0
  end

  test "the garage goes through opening to open and toasts at the end" do
    patch device_path(devices(:garage)), params: { state: "opening" }, as: :turbo_stream
    assert_select "turbo-stream[targets='.device-#{devices(:garage).id}'] .tile.is-moving .tile-state", "Opening…"
    patch device_path(devices(:garage)), params: { state: "open" }, as: :turbo_stream
    assert_select "turbo-stream[target=toasts] .toast-msg", "Garage open"
  end

  test "a scene applies its levels, highlights itself and offers Undo" do
    post scene_activations_path, params: { scene_id: scenes(:movie).id }, as: :turbo_stream
    assert_not devices(:pendants).reload.on?
    activation = SceneActivation.last
    assert_select "turbo-stream[target=control-scenes] .scene.is-on", "Movie"
    assert_select "turbo-stream[targets='.device-#{devices(:pendants).id}']", 1
    assert_select "turbo-stream[targets='.device-#{devices(:floor_lamp).id}'] .tile-state", "15%"
    assert_select "turbo-stream[target=toasts] .toast-msg", /Movie\s*scene on/
    assert_select "turbo-stream[target=toasts] form[action=?]", scene_activation_path(activation)

    delete scene_activation_path(activation), as: :turbo_stream
    assert devices(:pendants).reload.on?
    assert_select "turbo-stream[target=control-scenes] .scene.is-on", 0
  end

  test "the lights sheet lists every light, on first, with Turn everything off and its Undo" do
    get devices_path(kind: "lights")
    assert_select ".sheet-body[data-sheet-class='sheet--wide'] .sheet-h", "Lights"
    assert_select ".tiles--sheet .tile", 5
    assert_select ".tiles--sheet .tile:first-child.is-on", 1
    assert_select "form[action=?]", lights_path

    delete lights_path, as: :turbo_stream
    assert_empty households(:primary).lights_on
    assert_select "turbo-stream[target=toasts] .toast-msg", "Turned off 3 lights"
    assert_select "turbo-stream[target=toasts] form[action=?]", scene_activation_path(SceneActivation.last)
    delete scene_activation_path(SceneActivation.last), as: :turbo_stream
    assert_equal 3, households(:primary).lights_on.size
  end

  test "the security sheet lists locks and the garage, and Lock all doors locks them" do
    devices(:side_door).apply(locked: false)
    get devices_path(kind: "security")
    assert_select ".sheet-h", "Security"
    assert_select ".tiles--sheet .tile", 3
    assert_select "form[action=?]", locks_path

    post locks_path, as: :turbo_stream
    assert devices(:side_door).reload.locked?
    assert_select "turbo-stream[target=toasts] .toast-msg", "All doors locked"
  end

  test "the garage sheet asks to slide, with direction-specific copy" do
    get garage_device_path(devices(:garage))
    assert_select ".sheet-h", "Open the garage?"
    assert_select ".sheet-p", "Make sure the driveway is clear."
    assert_select ".slide-confirm[data-controller=slide] .sc-label", "Slide to open →"
    devices(:garage).apply(state: "open")
    get garage_device_path(devices(:garage))
    assert_select ".sheet-h", "Close the garage?"
  end

  test "the camera sheet shows a large snapshot" do
    get camera_path(cameras(:front))
    assert_select ".sheet-body[data-sheet-class='sheet--cam'] .cam-big img[src*='porch-steps']"
    assert_select ".cam-big .tk-live", /Front Porch/
  end

  test "the thermostat steps and changes mode, re-rendering the panel and summary" do
    patch thermostat_path, params: { delta: 0.5 }, as: :turbo_stream
    assert_equal 22.0, thermostats(:main).reload.target_temperature
    assert_select "turbo-stream[target=control-climate] .th-set .num", "22°"
    assert_select "turbo-stream[target=control-sum] .sum[data-sum=climate] small", "Heating to 22°"
    assert_select "turbo-stream[target=today-status]", 1
    patch thermostat_path, params: { mode: "off" }, as: :turbo_stream
    assert_select "turbo-stream[target=control-climate] .th-verb--off", "Off"
    assert_select "turbo-stream[target=control-sum] .sum[data-sum=climate] small", "System off"
  end

  test "play/pause toggles the player and the summary" do
    patch media_player_path, as: :turbo_stream
    assert_not media_players(:kitchen).reload.playing?
    assert_select "turbo-stream[target=control-media] .np-btn[data-playing=false]", 1
    assert_select "turbo-stream[target=control-sum] .sum[data-sum=media] b", "Paused"
  end
end
