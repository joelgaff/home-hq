require "test_helper"

# The dashboard carries the household's clock format for the browser clocks, and the thermostat
# buttons step by the unit.
class UnitsDisplayTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  test "the page tells the browser clocks the format" do
    get root_path
    assert_select "#stage[data-shell-clock-value='12']", 1
    households(:primary).update!(clock_format: "24")
    get root_path
    assert_select "#stage[data-shell-clock-value='24']", 1
    assert_select "#today-clock .h-time", /15:18/
    assert_select "#today-clock .h-ampm", ""
  end

  test "the climate buttons step by the unit" do
    get control_path
    assert_select "#control-climate [data-delta='-0.5']", 1
    households(:primary).update!(temperature_unit: "f")
    get control_path
    assert_select "#control-climate [data-delta='-1']", 1
    assert_select "#control-climate [data-delta='1']", 1
  end
end
