require "test_helper"

class ScreenTest < ActiveSupport::TestCase
  test "needs a name" do
    screen = Screen.new(household: households(:primary))
    assert_not screen.valid?
    assert_includes screen.errors[:name], "can't be blank"
  end

  test "gets a one-time enrollment token when created" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
    assert screen.enrollment_token.present?
    assert_nil screen.session_token
    assert_not screen.enrolled?
  end

  test "enrolling issues a session token and spends the enrollment token" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
    screen.enroll!
    assert screen.session_token.present?
    assert_nil screen.enrollment_token
    assert screen.enrolled?
  end

  # ---------------------------------------------------------------- settings (plan: per-screen settings)
  test "a new screen is night from 10 PM to 6 AM, starts on Today and reloads at 3 AM" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
    assert_equal [ 22, 6 ], [ screen.night_from, screen.night_to ]
    assert_equal "home", screen.default_view
    assert_equal 3, screen.reload_hour
    assert_equal "10 PM – 6 AM", screen.night_hours_label
    assert_equal "off", screen.night_style, "the gap review's default: the screen goes dark overnight"
    assert_equal "10 PM – 6 AM, screen off", screen.night_label
    screen.night_style = "clock"
    assert_equal "10 PM – 6 AM, red clock", screen.night_label
  end

  test "the night style is off or the red clock" do
    screen = Screen.new(household: households(:primary), name: "x", night_style: "disco")
    assert_not screen.valid?
    assert_includes screen.errors[:night_style], "is not included in the list"
  end

  test "night hours wrap midnight, or not, or are off when equal" do
    screen = Screen.new(household: households(:primary), name: "x", night_from: 22, night_to: 6)
    assert screen.night?(23)
    assert screen.night?(0)
    assert screen.night?(5)
    assert_not screen.night?(6)
    assert_not screen.night?(12)

    screen.assign_attributes(night_from: 1, night_to: 5)
    assert screen.night?(1)
    assert_not screen.night?(5)
    assert_not screen.night?(23)

    screen.assign_attributes(night_from: 7, night_to: 7)
    assert_not screen.night?(7)
    assert_equal "Never", screen.night_hours_label
  end

  test "the default view is one of the views, the hours are hours, and the reload hour may be off" do
    screen = Screen.new(household: households(:primary), name: "x", default_view: "nonsense", night_from: 25, night_to: -1, reload_hour: 24)
    assert_not screen.valid?
    assert_includes screen.errors[:default_view], "is not included in the list"
    assert screen.errors[:night_from].any?
    assert screen.errors[:night_to].any?
    assert screen.errors[:reload_hour].any?

    screen.assign_attributes(default_view: "calendar", night_from: 21, night_to: 7, reload_hour: nil)
    assert screen.valid?
  end
end
