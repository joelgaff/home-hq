require "test_helper"
require "turbo/broadcastable/test_helper"

# Per-screen settings (plan: per-screen settings): night hours, the default view and the nightly
# reload hour, edited by an adult on the screen's page and baked into the page the screen shows.
class ScreenSettingsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup { @screen = Screen.create!(household: households(:primary), name: "Kitchen") }

  test "an adult edits a screen's settings" do
    sign_in_as users(:owner)
    get edit_screen_path(@screen)
    assert_response :success
    assert_select "select[name='screen[default_view]'] option[selected][value=home]", 1
    assert_select "select[name='screen[night_from]'] option[selected][value='22']", 1
    assert_select "select[name='screen[reload_hour]'] option[selected][value='3']", 1
    assert_select "select[name='screen[night_style]'] option[selected][value=off]", 1

    patch screen_path(@screen), params: { screen: { name: "Hall", night_from: 21, night_to: 7, night_style: "clock", default_view: "calendar", reload_hour: 4 } }
    assert_redirected_to screen_path(@screen)
    @screen.reload
    assert_equal [ "Hall", 21, 7, "clock", "calendar", 4 ], [ @screen.name, @screen.night_from, @screen.night_to, @screen.night_style, @screen.default_view, @screen.reload_hour ]

    get screen_path(@screen)
    assert_select "p", text: /Night 9 PM – 7 AM, red clock · starts on Calendar · reloads at 4 AM/

    patch screen_path(@screen), params: { screen: { reload_hour: "" } }
    assert_redirected_to screen_path(@screen)
    assert_nil @screen.reload.reload_hour
    get screen_path(@screen)
    assert_select "p", text: /never reloads/
  end

  test "a bogus view is refused" do
    sign_in_as users(:owner)
    patch screen_path(@screen), params: { screen: { default_view: "nonsense" } }
    assert_response :unprocessable_entity
    assert_equal "home", @screen.reload.default_view
  end

  test "the screen's page carries its settings for the shell; the app carries the defaults" do
    @screen.update!(night_from: 21, night_to: 7, night_style: "clock", default_view: "calendar", reload_hour: 4)
    get enroll_screen_path(@screen.enrollment_token)
    get root_path
    assert_select "#stage[data-shell-night-from-value='21'][data-shell-night-to-value='7'][data-shell-view-value=calendar][data-shell-reload-hour-value='4'][data-night-style=clock]", 1
    assert_select "turbo-cable-stream-source", 2

    reset!  # a person's browser, without the screen cookie
    sign_in_as users(:owner)
    get root_path
    assert_select "#stage[data-shell-night-from-value='22'][data-shell-night-to-value='6'][data-shell-view-value=home][data-night-style=off]", 1
    assert_select "#stage[data-shell-reload-hour-value]", 0
    assert_select "turbo-cable-stream-source", 1
  end

  test "a screen whose settings change is told to reload" do
    sign_in_as users(:owner)
    assert_no_turbo_stream_broadcasts(@screen) { patch screen_path(@screen), params: { screen: { name: "Hall" } } }
    streams = capture_turbo_stream_broadcasts(@screen) { patch screen_path(@screen), params: { screen: { default_view: "calendar" } } }
    assert_equal [ "reload" ], streams.map { |s| s["action"] }
  end
end
