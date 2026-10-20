require "test_helper"

# Ambient / night overlays, the demo drawer, and the alert templates (docs/ui-spec.md §1.8, §1.9).
class OverlaysTest < ActionDispatch::IntegrationTest
  setup do
    show_on_screen
    travel_to Time.utc(2026, 10, 14, 15, 18)
  end

  test "ambient: slideshow stage, big clock, weather, next event pill and presence" do
    get root_path
    assert_select "#ambient[data-controller=ambient]" do
      assert_select ".amb-stage[data-controller=slideshow][data-slideshow-interval-value='14000']", 1
      assert_select ".amb-info .amb-time", /3:18/
      assert_select ".amb-info .amb-date", /Wednesday, October 14/
      assert_select "turbo-frame#ambient-info .amb-wx .num", "15°"
      assert_select "turbo-frame#ambient-info .amb-wx small", "Rain from 4 PM"
      assert_select "turbo-frame#ambient-info .amb-next", /Piano lesson · 3:45 PM/
      assert_select "turbo-frame#ambient-info .amb-who .avatar", 4
      assert_select "turbo-frame#ambient-info .amb-who .avatar--away", 2
    end
  end

  test "night: red clock, first thing tomorrow after 6 AM, the house's security line" do
    get root_path
    assert_select "#night[data-controller=night] .nt-inner" do
      assert_select ".nt-time", /3:18/
      assert_select "turbo-frame#night-info .nt-line", /15° · First up tomorrow:\s*Gym\s*7:00 AM · Claudia/
      assert_select "turbo-frame#night-info .nt-lock", "House locked"
    end
    devices(:garage).apply(state: "open")
    get root_path
    assert_select "#night .nt-lock", "Garage open"
  end

  test "night before 6 AM looks at today, and says so when nothing is early" do
    travel_to Time.utc(2026, 10, 15, 4, 0)
    get root_path
    assert_select "#night .nt-line", /First up today:\s*Gym/
    events(:gym_tomorrow).destroy
    get root_path
    assert_select "#night .nt-line", /Nothing early tomorrow/
  end

  test "the demo drawer: time presets, modes, alerts and calendar data modes" do
    get root_path
    assert_select "#demo[data-controller=demo] .demo-panel" do
      assert_select ".demo-head h2", "Demo controls"
      assert_select "button[data-time]", 5
      assert_select "button[data-time=real]", "Real time"
      assert_select "button[data-mode=ambient]", "Ambient"
      assert_select "button[data-fastidle]", "Idle: fast"
      assert_select "button[data-alert]", 4
      assert_select "button[data-cal=normal].is-on", "Normal day"
      assert_select "button[data-cal=busy]", "Overloaded"
    end
  end

  test "a demo time preset shifts the dashboard's clock for this browser only" do
    patch demo_path, params: { time: "7:10" }
    assert_redirected_to root_path
    get root_path
    assert_select "#today-clock .h-time", /7:10\s*AM/
    assert_select "#demo button[data-time='7:10'].is-on", 1
    patch demo_path, params: { time: "real" }
    get root_path
    assert_select "#today-clock .h-time", /3:18\s*PM/
  end

  test "the demo calendar modes empty or overload the day" do
    patch demo_path, params: { calendar: "empty" }
    get root_path
    assert_select "#today-hero .h-hero--empty", 1
    assert_select "#demo button[data-cal=empty].is-on", 1
    patch demo_path, params: { calendar: "busy" }
    get root_path
    assert_select "#today-lanes .h-lane:nth-child(2) .h-ev-n", text: "Plumber window", count: 0
    assert_select "#calendar .ev-title", text: "Plumber window", count: 1
    patch demo_path, params: { calendar: "normal" }
    get root_path
    assert_select "#calendar .ev-title", text: "Plumber window", count: 0
  end

  test "the alert templates: doorbell and leak takeovers, garage and package banners" do
    get root_path
    assert_select "#takeover[data-controller=alerts]"
    assert_select "template[data-alerts-target=doorbell] .takeover--door" do
      assert_select ".tk-live", /LIVE · Front Porch/
      assert_select ".tk-title", /Someone’s at\s*the front door/
      assert_select "[data-talk]", /Talk/
      assert_select "[data-unlock][data-controller=hold][data-hold-ms-value='1000'][data-device-url=?]", device_path(devices(:front_door))
      assert_select "[data-dismiss]", /Dismiss/
      assert_select ".tk-cam img[src*='picsum']", 1
    end
    assert_select "template[data-alerts-target=leak] .takeover--alarm" do
      assert_select ".tk-huge", "Water leak"
      assert_select "[data-valve][data-controller=hold][data-hold-ms-value='1200']", /Hold to shut off water/
      assert_select "[data-ack]", /Acknowledge/
    end
    assert_select "template[data-alerts-target=garage] .banner" do
      assert_select ".banner-text b", "Garage open for 15 min"
      assert_select ".banner-text span", "No one is in the garage · Wes is 12 min away"
      assert_select "[data-act]", "Close garage"
      assert_select "[data-x]", "Leave open"
    end
    assert_select "template[data-alerts-target=package] .banner.banner--ink" do
      assert_select ".banner-text b", "Package delivered"
      assert_select "[data-act]", "View camera"
    end
  end
end
