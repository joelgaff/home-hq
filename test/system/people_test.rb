require "application_system_test_case"

# The People view in the browser (plan: People view): tap an avatar for that person's page, tick a
# to-do off there and see the Today lane follow, come back to everyone.
class PeopleTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    households(:primary).update!(demo: false)
    @todo = households(:primary).todos.create!(person: people(:buzzsaw), title: "Pack swim bag", due_on: Date.new(2026, 10, 14), stars: 2)
    show_on_screen
  end

  test "a kid's page opens from the avatars, a to-do ticks off with a toast, and Everyone goes back" do
    assert_selector "#today-lanes .h-todo .h-ev-n", text: "Pack swim bag"
    find(".rail-item[data-go=people]").click
    assert_selector "#view-people.is-active"
    find("#people .pp", text: /buzzsaw/i).click
    assert_selector "#people .my-day", wait: 5
    assert_selector "#people .my-day-ring .num", text: %r{\d+/\d+}
    find("#people .my-todos .my-todo", text: "Pack swim bag").click
    assert_selector "#toasts .toast", text: /Pack swim bag.*\+2★ Buzzsaw/i, wait: 5
    assert @todo.reload.done?
    assert_no_selector "#today-lanes .h-todo .h-ev-n", text: "Pack swim bag", wait: 5
    assert_selector "#people .my-todos .my-todo.is-done", text: "Pack swim bag", wait: 5
    find("#people .my-back").click
    assert_selector "#people .pp", count: 4, wait: 5
  end
end
