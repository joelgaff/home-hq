require "test_helper"

# Weather copy rules from docs/ui-spec.md §1.1.
class WeatherReportTest < ActiveSupport::TestCase
  setup { @report = weather_reports(:today) }

  test "the current hour's reading with its label and highs" do
    now = @report.outlook(at: Time.utc(2026, 10, 14, 15, 18))
    assert_equal 15, now.temperature
    assert_equal "cloud", now.condition
    assert_equal "Overcast", now.label
    assert_equal 17, now.high
    assert_equal 8, now.low
  end

  test "rain later: Rain from X, and a jacket for soccer when soccer is still ahead" do
    now = @report.outlook(at: Time.utc(2026, 10, 14, 15, 18))
    assert_equal "Rain from 4 PM", now.summary
    assert_equal "Pack a rain jacket for soccer", now.advice
  end

  test "rain later with no soccer ahead: Grab a rain jacket" do
    events(:soccer).destroy
    now = @report.outlook(at: Time.utc(2026, 10, 14, 15, 18))
    assert_equal "Grab a rain jacket", now.advice
  end

  test "the outdoor words are the household's: any of them in an event ahead names it; none, the plain advice" do
    events(:soccer).update!(title: "Hike at Bent Creek")
    households(:primary).update!(rain_keywords: "practice, hike")
    assert_equal "Pack a rain jacket for hike", @report.reload.outlook(at: Time.utc(2026, 10, 14, 15, 18)).advice
    households(:primary).update!(rain_keywords: "")
    assert_equal "Grab a rain jacket", @report.reload.outlook(at: Time.utc(2026, 10, 14, 15, 18)).advice
  end

  test "raining now: Rain until X and umbrella weather" do
    now = @report.outlook(at: Time.utc(2026, 10, 14, 17, 5))
    assert_equal "Rain until 8 PM", now.summary
    assert_equal "Umbrella weather", now.advice
  end

  test "dry and cool before noon: jacket weather; dry and warm: light layers" do
    cool = @report.outlook(at: Time.utc(2026, 10, 14, 21, 0))
    assert_equal "Clear and cool", cool.summary
    assert_equal "Jacket weather", cool.advice

    @report.hourly_forecasts.where(hour: 21..23).update_all(temperature: 20)
    warm = @report.reload.outlook(at: Time.utc(2026, 10, 14, 21, 0))
    assert_equal "Dry all day", warm.summary
    assert_equal "Light layers", warm.advice
  end

  test "seven hourly cells starting now, wrapping past midnight" do
    cells = @report.hourly(at: Time.utc(2026, 10, 14, 21, 0), count: 7)
    assert_equal %w[Now 10p 11p 12a 1a 2a 3a], cells.map(&:label)
    assert_equal [ 10, 10, 9, 9, 9, 8, 8 ], cells.map(&:temperature)
    assert cells.none?(&:wet?)
    assert @report.hourly(at: Time.utc(2026, 10, 14, 16, 0), count: 1).first.wet?
  end
end
