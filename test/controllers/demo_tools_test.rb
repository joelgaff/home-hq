require "test_helper"

# The demo drawer, its presets and the startup tip (ui-spec §0, §1.9) are for a demo household
# (plan: milestone 3, second review). A real household's frame has none of it to find.
class DemoToolsTest < ActionDispatch::IntegrationTest
  test "a demo household's frame has the drawer, the tip and the clock hold" do
    show_on_screen
    get root_path
    assert_select "#demo", 1
    assert_select "#tpl-tip", 1
    assert_select "#railClock[data-controller=hold]", 1
    patch demo_path, params: { time: "7:10" }
    assert_redirected_to root_path
  end

  test "a real household's frame has no demo tools and the presets are refused" do
    households(:primary).update!(demo: false)
    show_on_screen
    get root_path
    assert_response :success
    assert_select "#demo", 0
    assert_select "#tpl-tip", 0
    assert_select "#railClock[data-controller=hold]", 0
    assert_select "#railClock", 1
    patch demo_path, params: { time: "7:10" }
    assert_response :not_found
  end

  test "a fresh start turns the demo tools off" do
    assert households(:primary).demo?
    households(:primary).fresh_start!
    assert_not households(:primary).reload.demo?
  end
end
