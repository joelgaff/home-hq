require "application_system_test_case"

# Modes, the demo drawer and alerts in the browser (docs/ui-spec.md §0, §1.8, §1.9).
class OverlaysTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @screen = show_on_screen
  end

  test "A and N switch modes; tapping ambient returns to day, tapping night gives nightdash" do
    @screen.update!(night_style: "clock")  # Wes's red clock (the default night style is dark)
    assert_selector "#stage[data-night-style=clock]", visible: :all, wait: 10
    find("body").send_keys("a")
    assert_selector "#stage[data-mode=ambient]"
    assert_selector "#ambient .amb-time", text: "3:18"
    assert_selector "#ambient .amb-stage .slide", wait: 5
    find("#ambient").click
    assert_selector "#stage[data-mode=day]"
    assert_selector "#view-home.is-active"

    find("body").send_keys("n")
    assert_selector "#stage[data-mode=night]"
    assert_selector "#night .nt-time", text: "3:18"
    find("#night").click
    assert_selector "#stage[data-mode=nightdash]"
  end

  test "the demo drawer opens with D and its presets reload the dashboard" do
    find("body").send_keys("d")
    assert_selector "#demo.is-open .demo-panel h2", text: /demo controls/i
    click_on "Empty day"
    assert_selector "#today-hero .h-hero--empty"
    find("body").send_keys("d")
    assert_selector "#demo button[data-cal=empty].is-on"
    click_on "7:10 AM"
    assert_selector "#today-clock .h-time", text: /7:10\s*AM/
    assert_selector "#railClock", text: /7:10\s*AM/
  end

  test "the doorbell takeover and the package banner come from the drawer" do
    find("body").send_keys("d")
    click_on "Doorbell"
    assert_selector "#takeover.is-open.takeover--door .tk-title", text: /someone’s at/i
    assert_selector "#takeover .label", text: /doorbell ·\s*3:18 PM/i
    find("#takeover [data-dismiss]").click
    assert_no_selector "#takeover.is-open"

    find("body").send_keys("d")
    click_on "Package"
    assert_selector "#banners .banner.banner--ink.is-in .banner-text b", text: /package delivered/i
    find("#banners [data-x]").click
    assert_no_selector "#banners .banner"
  end

  test "a takeover forces day mode and the idle machine leaves it alone" do
    find("body").send_keys("n")
    assert_selector "#stage[data-mode=night]"
    execute_script("document.dispatchEvent(new CustomEvent('demo:alert', { detail: { kind: 'leak' } }))")
    assert_selector "#stage[data-mode=day]"
    assert_selector "#takeover.is-open.takeover--alarm .tk-huge", text: /water leak/i
    find("#takeover [data-ack]").click
    assert_no_selector "#takeover.is-open"
    assert_selector "#toasts .toast-msg", text: /leak acknowledged/i
  end

  test "the startup tip appears once" do
    assert_selector "#toasts .toast-msg", text: /press and hold the\s*clock/i, wait: 10
  end
end

# Night follows the screen's hours (plan: per-screen settings): night ends when they do instead of
# sticking until touched, ambient becomes night when they begin, and the screen reloads itself
# once a night at its reload hour.
class ScreenNightTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @screen = show_on_screen
  end

  # The shell checks the hours on the minute; force the next minute instead of waiting for it.
  def next_minute
    execute_script("window.shell.lastMinute = -1; window.shell.tick()")
  end

  test "night ends with the night hours, and ambient becomes night when they begin" do
    @screen.update!(night_from: 22, night_to: 6)
    visit root_path
    find("body").send_keys("n")
    assert_selector "#stage[data-mode=night]"
    next_minute
    assert_selector "#stage[data-mode=day]"
    assert_selector "#view-home.is-active"

    @screen.update!(night_from: 15, night_to: 16)
    visit root_path
    find("body").send_keys("a")
    assert_selector "#stage[data-mode=ambient]"
    next_minute
    assert_selector "#stage[data-mode=night]"
  end

  test "a dark night screen shows nothing until tapped; the red clock style shows the clock" do
    find("body").send_keys("n")
    assert_selector "#stage[data-mode=night][data-night-style=off]"
    assert_no_selector "#night .nt-inner"
    assert_selector "#night .nt-inner", visible: :all
    find("#night").click
    assert_selector "#stage[data-mode=nightdash]"

    @screen.update!(night_style: "clock")
    assert_selector "#stage[data-night-style=clock]", visible: :all, wait: 10
    find("body").send_keys("n")
    assert_selector "#stage[data-mode=night] #night .nt-inner .nt-time", text: "3:18"
  end

  test "the screen reloads itself at its reload hour, once" do
    travel_to Time.utc(2026, 10, 14, 15, 0)
    @screen.update!(reload_hour: 15, default_view: "calendar")
    assert_selector "#stage[data-shell-reload-hour-value='15']", visible: :all, wait: 10  # the setting change reloaded this page
    visit "/up"  # then a cold start: a visit that only changes the hash is a same-document navigation
    visit root_path(anchor: "shopping")
    assert_selector "#view-calendar.is-active"
    find(".rail-item[data-go=shopping]").click
    assert_selector "#view-shopping.is-active"
    execute_script("window.__stageMark = 1")
    next_minute
    assert_selector "#view-calendar.is-active", wait: 5
    assert_nil evaluate_script("window.__stageMark")
    assert_equal "#calendar", evaluate_script("location.hash")
  end
end

# Alerts from the house in the browser (plan: milestone 6): the stream action opens the takeover
# with the alert's camera, dismissing acknowledges it, and banners carry the alert's text.
class HouseAlertBrowserTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    households(:primary).update!(demo: false)
    @camera = households(:primary).cameras.create!(name: "Doorbell", entity_id: "camera.doorbell")
    show_on_screen(name: "Kitchen")
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 10
  end

  # The acknowledgement is a request the page sends after the click; give it a moment.
  def acknowledged?(alert)
    20.times do
      return true if alert.reload.acknowledged_at.present?
      sleep 0.25
    end
    false
  end

  test "a doorbell alert takes over with its camera and is acknowledged on dismiss" do
    alert = households(:primary).home_alerts.create!(kind: "doorbell", camera: @camera)
    assert_selector "#takeover.is-open.takeover--door", wait: 10
    assert_selector "#takeover .tk-cam img[src*='/cameras/#{@camera.id}/snapshot']"
    assert_selector "#stage[data-mode=day]"
    find("#takeover [data-dismiss]").click
    assert_no_selector "#takeover.is-open"
    assert acknowledged?(alert), "dismiss acknowledges"
    assert_equal "Kitchen", alert.acknowledged_by
  end

  test "a garage-open alert is a banner with the alert's words; Leave open acknowledges it" do
    alert = households(:primary).home_alerts.create!(kind: "garage_open", device: devices(:garage), message: "Garage open for 15 min · Wes is 12 min away")
    assert_selector "#banners .banner.banner--amber .banner-text b", text: "Garage open for 15 min", wait: 10
    assert_selector "#banners .banner-text span", text: "Wes is 12 min away"
    find("#banners [data-x]").click
    assert_no_selector "#banners .banner"
    assert acknowledged?(alert)
  end
end
