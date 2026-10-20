require "test_helper"

# To-dos on the screens (plan: People view): added from the frame or a phone, completed with a
# tap, shown in the Today lanes (timed ones in time order with the events, untimed as a "To do"
# group), Anyone's with the Anyone chores, and managed under Settings.
class TodosTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    show_on_screen(name: "Kitchen")
  end

  test "add, complete, undo and remove a to-do from the frame, with the lanes replaced" do
    post todos_path, params: { todo: { title: "Pack swim bag", person_id: people(:buzzsaw).id, due_on: "2026-10-14", stars: 1 } }, as: :turbo_stream
    assert_response :success
    todo = @household.todos.last
    assert_equal [ "Pack swim bag", people(:buzzsaw), Date.new(2026, 10, 14), 1, "Kitchen" ], [ todo.title, todo.person, todo.due_on, todo.stars, todo.created_by ]
    assert_select "turbo-stream[action=replace][target=today-lanes]", 1
    assert_select "turbo-stream[target=toasts]", text: /to-do/i

    patch complete_todo_path(todo), as: :turbo_stream
    assert todo.reload.done?
    assert_select "turbo-stream[target=toasts]", text: /\+1★/
    patch undo_todo_path(todo), as: :turbo_stream
    assert_not todo.reload.done?
    delete todo_path(todo), as: :turbo_stream
    assert_nil Todo.find_by(id: todo.id)
  end

  test "the Today lanes show today's to-dos: timed ones with the events in order, untimed as a To do group" do
    @household.todos.create!(person: people(:wes), title: "Pick up dry cleaning", due_at: Time.utc(2026, 10, 14, 17))
    @household.todos.create!(person: people(:wes), title: "Call the plumber")
    @household.todos.create!(person: people(:wes), title: "Yesterday's", due_on: Date.new(2026, 10, 13))
    @household.todos.create!(person: people(:wes), title: "Tomorrow's", due_on: Date.new(2026, 10, 15))
    get today_path(part: "lanes")
    assert_select ".h-lane" do |lanes|
      wes = lanes.find { |l| l.css(".h-lane-head b").text == "Wes" }
      items = wes.css(".h-ev .h-ev-n, .h-todo .h-ev-n").map(&:text)
      assert_includes items, "Pick up dry cleaning"
      assert items.index("Pick up dry cleaning") < items.index("Dinner at Nonna's"), "a 5 PM to-do before a 6:30 dinner"
      assert_equal [ "Yesterday's", "Call the plumber" ], wes.css(".h-todos .h-todo .h-ev-n").map(&:text), "overdue first, then undated, in the To do group"
      assert_not_includes wes.text, "Tomorrow's"
    end
    assert_select ".h-lane form.h-todo-form[action*='/complete']", minimum: 1
  end

  test "Anyone's to-dos sit with the Anyone chores" do
    @household.todos.create!(person: nil, title: "Water the plants", due_on: Date.new(2026, 10, 14))
    get chores_path
    assert_select ".ch-lane[data-lane=any] .ch-todo", text: /Water the plants/
  end

  test "an adult manages to-dos under Settings" do
    reset!
    sign_in_as users(:owner)
    get settings_path
    assert_select "a[href=?]", settings_todos_path
    post settings_todos_path, params: { todo: { title: "Renew passports", person_id: "", due_on: "2026-11-01" } }
    todo = @household.todos.find_by!(title: "Renew passports")
    assert_nil todo.person
    get settings_todos_path
    assert_select "li", text: /Renew passports.*Anyone/m
    patch settings_todo_path(todo), params: { todo: { title: "Renew the passports" } }
    assert_equal "Renew the passports", todo.reload.title
    delete settings_todo_path(todo)
    assert_nil Todo.find_by(id: todo.id)
  end
end
