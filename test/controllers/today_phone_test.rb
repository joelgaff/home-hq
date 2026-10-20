require "test_helper"

# Today on a phone (the approved mockup): the clock row carries the "Me" avatar, and the four
# person lanes give way to one "Rest of today" agenda of everyone's remaining events.
class TodayPhoneTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  test "a person's page has the agenda and the Me link, in time order" do
    sign_in_as users(:owner)
    get root_path
    assert_select "#view-home .h-me[data-go=people]", 1
    assert_select "#view-home turbo-frame#today-agenda", 1
    assert_select "#today-agenda .h-ag[data-ev]" do |rows|
      titles = rows.map { |r| r.css(".h-ag-n").text }
      assert_equal [ "Piano lesson", "Soccer practice", "Dinner at Nonna's" ], titles
    end
    assert_select "#today-agenda .h-ag", /3:45/
    assert_select "#today-agenda .h-ag.is-family .avatar", "★"
    assert_select "#today-agenda .h-ag .avatar", minimum: 3
  end

  test "the agenda re-renders on its own as a part" do
    sign_in_as users(:owner)
    get today_path(part: "agenda")
    assert_response :success
    assert_select "turbo-frame#today-agenda .h-ag", 3
  end

  test "the frame renders neither the agenda nor the Me link" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen")
    get enroll_screen_path(screen.enrollment_token)
    get root_path
    assert_select "#today-agenda", 0
    assert_select ".h-me", 0
    assert_select "#today-lanes", 1
  end
end
