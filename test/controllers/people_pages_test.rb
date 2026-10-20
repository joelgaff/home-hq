require "test_helper"

# The People view (plan: People view): on the frame, four big avatars and, a tap away, each
# person's page: a kid's "My day" (progress rings, stars, chores, to-dos, schedule, the week
# strip) or an adult's week (schedule, to-dos, chores, what needs them). A phone's Me shows the
# same sections.
class PeoplePagesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @household.todos.create!(person: people(:buzzsaw), title: "Pack swim bag", due_on: Date.new(2026, 10, 14), stars: 1)
    @household.todos.create!(person: people(:wes), title: "Call the plumber")
  end

  test "the frame's People view lists the avatars as links into the people frame, and is a piece" do
    show_on_screen
    get root_path
    assert_select "#view-people turbo-frame#people .people a[href=?][data-turbo-frame=people]", people_path(person: people(:buzzsaw).id)
    assert_equal "people/people", Pieces::REGISTRY["people"]
  end

  test "a kid's page is My day" do
    show_on_screen
    get people_path(person: people(:buzzsaw).id)
    assert_response :success
    assert_select "turbo-frame#people .my-day[data-person='#{people(:buzzsaw).id}']" do
      assert_select ".my-day-ring .num", text: %r{\d+/\d+}
      assert_select ".my-routine", minimum: 2
      assert_select ".my-stars", text: /★/
      assert_select ".my-chores .ch[data-chore-complete-url-value*='/chores/']", minimum: 1
      assert_select ".my-todos .my-todo", text: /Pack swim bag/
      assert_select ".my-todos form[action*='/todos/']", minimum: 1
      assert_select ".my-schedule"
      assert_select ".ch-week-row span", 7
      assert_select "a[href=?]", people_path, text: /everyone/i
    end
  end

  test "an adult's page is the week ahead" do
    show_on_screen
    get people_path(person: people(:wes).id)
    assert_select "turbo-frame#people .me-adult[data-person='#{people(:wes).id}']" do
      assert_select ".me-schedule .me-ev", minimum: 1
      assert_select ".me-todos .me-todo", text: /Call the plumber/
      assert_select ".me-chores .me-ch", minimum: 1
      assert_select ".me-needs", /Leave in|Next up/
    end
  end

  test "a phone's Me shows the same to-dos and a kid's rings" do
    people(:wes).update!(email: users(:owner).email)
    sign_in_as users(:owner)
    get root_path
    assert_select "#view-people .me-panel[data-lane='#{people(:wes).id}'] .me-todos .me-todo", text: /Call the plumber/
    assert_select "#view-people .me-panel[data-lane='#{people(:buzzsaw).id}'] .my-day-ring", 1
  end
end
