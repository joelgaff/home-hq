require "test_helper"

# The People view takes the Agents rail slot (plan: Decisions). Milestone 1 shows the four
# avatars; each person's page comes with milestone 8.
class PeopleControllerTest < ActionDispatch::IntegrationTest
  test "the dashboard page carries a People view with an avatar per person" do
    show_on_screen
    get root_path
    assert_select "#view-people .people .pp", 4
    assert_select "#view-people .people .pp:first-child b", "Wes"
    assert_select "#view-people .people .pp:first-child .avatar", "W"
    assert_select "#view-people .people-note", /tap someone/i
  end
end
