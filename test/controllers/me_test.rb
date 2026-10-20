require "test_helper"

# "Me" on a phone (the approved mockup): the People view opens on the signed-in person, with the
# others one tap away; their day's presence, what needs them next, the next seven days of their
# schedule, and their chores today. To-dos arrive with milestone 8.
class MeTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  test "a person's page shows the signed-in person first, the others as picks" do
    people(:wes).update!(user: users(:owner))
    sign_in_as users(:owner)
    get root_path
    assert_select "#view-people .me[data-controller~=picker]", 1
    assert_select "#view-people .me-picks [data-pick]", 4
    assert_select "#view-people .me-picks [data-pick=#{people(:wes).id}].is-on", 1
    assert_select "#view-people .me-lanes[data-picked='#{people(:wes).id}']", 1
    assert_select "#view-people .me-panel.is-picked[data-lane=#{people(:wes).id}]", 1
    assert_select "#view-people .me-panel", 4
    assert_select "#view-people .me-panel[data-lane=#{people(:wes).id}]" do
      assert_select ".me-kicker", /Wednesday · Driving home · ETA 12 min/
      assert_select ".me-name", "Wes"
      assert_select ".me-needs", /Dinner at Nonna's/
      assert_select ".me-needs", /Leave in/
      assert_select ".me-schedule .me-ev" do |rows|
        assert_equal [ "Dinner at Nonna's", "Wes in Montréal" ], rows.map { |r| r.css(".me-ev-n").text }
      end
      assert_select ".me-schedule .me-ev .me-ev-t", /Today\s*6:30 PM/
      assert_select ".me-schedule .me-ev .me-ev-t", /Thu–Sat/
      assert_select ".me-chores .me-ch", 1
      assert_select ".me-chores .me-ch", /Take out recycling/
      assert_select ".me-chores .me-ch .ch-late", "Overdue"
    end
    assert_select "#view-people .me-foot", /owner@example.com/
    assert_select "#view-people .me-foot form[action=?]", session_path
    assert_select "#view-people .me-foot a[href=?]", settings_path
  end

  test "without a linked person the first person opens" do
    sign_in_as users(:owner)
    get root_path
    assert_select "#view-people .me-lanes[data-picked='#{people(:wes).id}']", 1
  end

  test "the frame keeps the four big avatars" do
    show_on_screen
    get root_path
    assert_select "#view-people .people .pp", 4
    assert_select "#view-people .me", 0
  end
end
