require "test_helper"

# The calendar on a phone (the approved mockup): Agenda / Day / Month, person chips that filter,
# agenda as one time-ordered list with the now marker, Day as one column.
class CalendarPhoneTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  test "a person's page opens the calendar in Agenda mode with phone modes and person chips" do
    sign_in_as users(:owner)
    get root_path
    assert_select "#view-calendar turbo-frame#calendar .cal.cal--agenda", 1
    assert_select "#calendar .cal-head .seg a", 3
    assert_select "#calendar .cal-head .seg a.is-on", "Agenda"
    assert_select "#calendar .cal-chips a", 5
    assert_select "#calendar .cal-chips a.is-on", /Everyone/
  end

  test "the frame keeps Today mode, the four modes and no chips" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen")
    get enroll_screen_path(screen.enrollment_token)
    get root_path
    assert_select "#view-calendar .cal.cal--day", 1
    assert_select "#calendar .cal-head .seg a", 4
    assert_select "#calendar .cal-chips", 0
  end

  test "agenda: all-day chips, rows in time order, past faded, the now marker, leave-by and company" do
    sign_in_as users(:owner)
    get calendar_path(mode: "agenda")
    assert_select ".cal--agenda .ag-allday .ad", "Pajama Day at school"
    assert_select ".cal--agenda .ag-row[data-ev]" do |rows|
      assert_equal [ "Dentist", "Piano lesson", "Soccer practice", "Dinner at Nonna's" ], rows.map { |r| r.css(".ag-title").text }
    end
    assert_select ".ag-item.is-past .ag-title", "Dentist"
    assert_select ".ag-now .num", "3:18"
    assert_select ".ag-row[data-ev=#{events(:piano).id}] .ag-meta", /3:45 – 4:30 PM · Ms. Park's Studio · Leave 3:33/
    assert_select ".ag-row[data-ev=#{events(:dentist).id}] .ag-meta", /with Claudia/
    assert_select ".ag-row.is-family[data-ev=#{events(:dinner).id}] .ag-meta", /Everyone/
    assert_select ".cal-head a[data-nav='1'][href=?]", calendar_path(mode: "agenda", date: "2026-10-15")
  end

  test "a person chip filters the agenda and travels with the navigation" do
    sign_in_as users(:owner)
    get calendar_path(mode: "agenda", person: people(:skidmark).id)
    assert_select ".cal-chips a.is-on", /Skidmark/
    assert_select ".ag-row .ag-title" do |titles|
      assert_equal [ "Piano lesson", "Dinner at Nonna's" ], titles.map(&:text)
    end
    assert_select ".cal-head a[data-nav='1'][href=?]", calendar_path(mode: "agenda", date: "2026-10-15", person: people(:skidmark).id)
    assert_select ".cal-head .seg a[href=?]", calendar_path(mode: "day", date: "2026-10-14", person: people(:skidmark).id)
  end

  test "Day mode on a phone is one column holding everyone's events, or one person's" do
    sign_in_as users(:owner)
    get calendar_path(mode: "day")
    assert_select ".cal-day .lanes.lanes--1 .lane", 1
    assert_select ".lanes--1 .lane .ev", 4
    assert_select ".lanes--1 .lane .ev.is-family .ev-title", "Dinner at Nonna's"
    get calendar_path(mode: "day", person: people(:buzzsaw).id)
    assert_select ".lanes--1 .lane .ev", 3
  end

  test "an empty agenda says so" do
    sign_in_as users(:owner)
    get calendar_path(mode: "agenda", date: "2026-10-20")
    assert_select ".cal--agenda .cal-empty", /Nothing on the calendar/
  end
end
