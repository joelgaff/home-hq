require "test_helper"

# Units and clock are household settings (plan: Our instance): °C or °F drives the thermostat's
# step and clamp and the weather advice threshold; the clock is 12- or 24-hour.
class UnitsTest < ActiveSupport::TestCase
  setup do
    @household = households(:primary)
    travel_to Time.utc(2026, 10, 14, 15, 18)
  end

  test "celsius: half-degree steps between 15 and 28, cool below 12" do
    assert_equal 0.5, thermostats(:main).step
    thermostats(:main).update!(target_temperature: 27.8)
    thermostats(:main).adjust!(0.5)
    assert_equal 28.0, thermostats(:main).reload.target_temperature
    assert_equal 12, @household.cool_below
  end

  test "fahrenheit: whole-degree steps between 60 and 82, cool below 54" do
    @household.update!(temperature_unit: "f")
    t = thermostats(:main).reload
    assert_equal 1, t.step
    t.update!(target_temperature: 70)
    t.adjust!(1)
    assert_equal 71, t.target_temperature
    t.update!(target_temperature: 81.5)
    t.adjust!(1)
    assert_equal 82, t.target_temperature
    t.adjust!(-30)
    assert_equal 60, t.target_temperature
    assert_equal 54, @household.cool_below
    assert_equal "°F", @household.degrees
  end

  test "the weather advice threshold follows the unit" do
    report = weather_reports(:today)
    report.hourly_forecasts.update_all(precipitation_chance: 0)
    report.hourly_forecasts.where(hour: 15).update_all(temperature: 13)
    assert_equal "Dry all day", report.outlook.summary, "13 °C is not cool"
    @household.update!(temperature_unit: "f")
    report.hourly_forecasts.where(hour: 15).update_all(temperature: 13)
    assert_equal "Clear and cool", report.reload.outlook.summary, "13 °F is cool"
  end

  test "the clock format is a setting" do
    assert_not @household.clock_24?
    @household.update!(clock_format: "24")
    assert @household.clock_24?
    assert_raises(ActiveRecord::RecordInvalid) { @household.update!(clock_format: "13") }
    assert_raises(ActiveRecord::RecordInvalid) { @household.update!(temperature_unit: "k") }
  end
end
