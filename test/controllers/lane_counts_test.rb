require "test_helper"

# Lane counts follow the people (plan: milestone 8; Simplifications 6 lifted): the Today lanes,
# the Chores lanes (plus Anyone), the calendar's day columns and the People grid take one column
# per person, 1 to about 8, and go compact past five.
class LaneCountsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  test "four people: four lanes, five chores lanes, four calendar columns" do
    get root_path
    assert_select "#today-lanes[style*='--lanes:4']", 1
    assert_select "#chores .ch-lanes[style*='--lanes:5']", 1
    assert_select "#view-people .people[style*='--lanes:4']", 1
    get calendar_path(mode: "day")
    assert_select ".cal-day .lanes[style*='--lanes:4']", 1
    assert_select ".cal-day .allday-grid[style*='--lanes:4']", 1
  end

  test "six people: six lanes and the compact class; one person: one lane" do
    households(:primary).people.create!(name: "Nana", color: "#8957E5")
    households(:primary).people.create!(name: "Pop", color: "#D97757")
    get root_path
    assert_select "#today-lanes[style*='--lanes:6'].is-many", 1
    assert_select "#chores .ch-lanes[style*='--lanes:7'].is-many", 1
    households(:primary).people.where.not(name: "Wes").destroy_all
    get root_path
    assert_select "#today-lanes[style*='--lanes:1']", 1
    assert_select "#today-lanes.is-many", 0
  end
end
