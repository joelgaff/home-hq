require "test_helper"

# Times follow the household's clock setting (plan: Our instance): 12-hour with AM/PM (Wes's copy)
# or 24-hour.
class TimeFormatHelperTest < ActionView::TestCase
  include TimeFormatHelper

  setup do
    Current.household = households(:primary)
    @t = Time.utc(2026, 10, 14, 15, 18)
    @u = Time.utc(2026, 10, 14, 16, 30)
  end

  test "12-hour, Wes's copy" do
    assert_equal "3:18 PM", fmt_time(@t)
    assert_equal "3:18", fmt_time(@t, ampm: false)
    assert_equal "PM", fmt_ampm(@t)
    assert_equal "3:18 – 4:30 PM", fmt_range(@t, @u)
    assert_equal "4 PM", fmt_hour(@u.change(min: 0))
  end

  test "24-hour" do
    Current.household.update!(clock_format: "24")
    assert_equal "15:18", fmt_time(@t)
    assert_equal "15:18", fmt_time(@t, ampm: false)
    assert_equal "", fmt_ampm(@t)
    assert_equal "15:18 – 16:30", fmt_range(@t, @u)
    assert_equal "16:00", fmt_hour(@u.change(min: 0))
    assert_equal "09:05", fmt_time(Time.utc(2026, 10, 14, 9, 5))
  end
end
