require "test_helper"

# Getting started (the order that works): Settings shows the setup steps in dependency order with
# each one's status, chores are gated until a routine exists, and the list folds away once the
# essentials are done.
class SetupChecklistTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    @household = households(:primary)
  end

  test "a fresh household sees the steps in order, with chores waiting on routines" do
    @household.fresh_start!
    get settings_path
    assert_select ".setup" do
      assert_select ".setup-step", 7
      steps = css_select(".setup-step .setup-name").map(&:text)
      assert_equal [ "People", "Routines", "Chores", "Calendars", "Stores", "PINs", "Screen" ], steps
      assert_select ".setup-step[data-step=people].is-todo a[href=?]", settings_people_path
      assert_select ".setup-step[data-step=chores].is-blocked", text: /add a routine first/i
      assert_select ".setup-step[data-step=stores].is-todo", 1, "a fresh start keeps no stores"
    end
  end

  test "chores cannot be added before a routine exists" do
    @household.fresh_start!
    get new_settings_chore_path
    assert_redirected_to settings_routines_path
    assert_match(/routine first/i, flash[:alert])
    post settings_chores_path, params: { chore: { title: "Dishes" } }
    assert_redirected_to settings_routines_path
    assert_equal 0, @household.chores.count
    get settings_chores_path
    assert_select ".page-note", text: /routine first/i
  end

  test "steps turn done as they are taken, and the list folds away when the essentials are" do
    @household.fresh_start!
    @household.people.create!(name: "Joel", color: "#2D5BFF", email: users(:owner).email)
    routine = @household.routines.create!(name: "Morning", from_hour: 6, to_hour: 11)
    get settings_path
    assert_select ".setup-step[data-step=people].is-done", 1
    assert_select ".setup-step[data-step=routines].is-done", 1
    assert_select ".setup-step[data-step=chores].is-todo a[href=?]", new_settings_chore_path
    @household.chores.create!(routine: routine, title: "Dishes", emoji: "🍽️", stars: 1)
    @household.stores.create!(name: "Costco")
    @household.calendar_sources.create!(name: "Family", url: "https://calendar.example.com/f.ics")
    @household.people.first.update!(pin: "2468")
    Screen.create!(household: @household, name: "Kitchen").enroll!
    get settings_path
    assert_select ".setup.is-complete", 1
    assert_select ".setup-step.is-todo", 0
  end
end
