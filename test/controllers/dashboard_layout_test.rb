require "test_helper"

# Who is signed in picks the layout (plan: Small screens). A screen is the wall frame: a fixed
# 1280×800 stage, fullscreen landscape manifest. A person gets the device-width app: the same
# page with the phone layer under 700 px and a standalone, any-orientation manifest.
class DashboardLayoutTest < ActionDispatch::IntegrationTest
  test "a screen gets the frame layout" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen")
    get enroll_screen_path(screen.enrollment_token)
    get root_path
    assert_select "meta[name=viewport][content*='width=1280']", 1
    assert_select "body[data-layout=frame]", 1
    assert_select "link[rel=manifest]" do |links|
      assert_equal [ "/manifest.json?layout=frame" ], links.map { |l| l["href"] }
    end
    assert_select "#stage[data-shell-layout-value=frame]", 1
  end

  test "a person gets the app layout with the phone layer" do
    sign_in_as users(:owner)
    get root_path
    assert_select "meta[name=viewport][content*='width=device-width']", 1
    assert_select "meta[name=viewport][content*='viewport-fit=cover']", 1
    assert_select "body[data-layout=app]", 1
    assert_select "link[rel=manifest][href='/manifest.json']", 1
    assert_select "#stage[data-shell-layout-value=app]", 1
    assert_select "link[rel=stylesheet][href*='dashboard/phone']", 1
  end

  test "the manifest installs as a landscape fullscreen frame or a standalone phone app" do
    get "/manifest.json"
    app = JSON.parse(response.body)
    assert_equal "standalone", app["display"]
    assert_equal "any", app["orientation"]

    get "/manifest.json?layout=frame"
    frame = JSON.parse(response.body)
    assert_equal "fullscreen", frame["display"]
    assert_equal "landscape", frame["orientation"]
  end
end
