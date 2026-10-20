require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  # Temperatures are stored in the household's unit, so changing the unit converts what is stored
  # (the demo's Celsius figures would otherwise read as °F).
  test "switching the temperature unit converts the stored thermostat and weather figures" do
    household = households(:primary)
    household.update!(temperature_unit: "c")
    thermostat = household.thermostat
    thermostat.update!(current_temperature: 20.5, target_temperature: 21, outside_temperature: 10)
    report = household.weather_reports.create!(high: 18, low: 9, fetched_at: Time.current)
    report.hourly_forecasts.create!(hour: 15, temperature: 16, condition: "sun")

    household.update!(temperature_unit: "f")
    assert_equal [ 69, 70, 50 ], [ thermostat.reload.current_temperature, thermostat.target_temperature, thermostat.outside_temperature ].map(&:round)
    assert_equal [ 64, 48, 61 ], [ report.reload.high, report.low, report.hourly_forecasts.first.temperature ]

    household.update!(temperature_unit: "c")
    assert_equal 21, thermostat.reload.current_temperature.round
    assert_equal 18, report.reload.high
  end
end
