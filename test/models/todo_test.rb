require "test_helper"

# To-dos (plan: People view): one-off items for a person or Anyone, with an optional due date or
# time and optional stars for kids; done is a timestamp, undo clears it and takes the stars back.
class TodoTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    Current.household = @household
  end

  teardown { Current.reset }

  test "needs a title; a due time implies the due date; stars never go negative" do
    todo = @household.todos.new(person: people(:buzzsaw))
    assert_not todo.valid?
    todo.title = "Pack swim bag"
    todo.due_at = Time.utc(2026, 10, 14, 16)
    assert todo.valid?
    assert_equal Date.new(2026, 10, 14), todo.due_on
    todo.stars = -1
    assert_not todo.valid?
  end

  test "completing gives a kid the stars and undo takes them back; adults' to-dos carry none" do
    todo = @household.todos.create!(person: people(:buzzsaw), title: "Library book back", stars: 3)
    before = people(:buzzsaw).stars
    todo.complete!
    assert todo.done?
    assert_equal before + 3, people(:buzzsaw).reload.stars
    todo.undo!
    assert_not todo.done?
    assert_equal before, people(:buzzsaw).reload.stars

    grown = @household.todos.create!(person: people(:wes), title: "Call the plumber", stars: 2)
    grown.complete!
    assert_equal 0, people(:wes).star_entries.count
  end

  test "an Anyone to-do done by a kid gives that kid the stars" do
    todo = @household.todos.create!(person: nil, title: "Water the plants", stars: 2)
    todo.complete!(by: people(:skidmark))
    assert_equal [ people(:skidmark), 2 ], [ todo.done_by, people(:skidmark).star_entries.last.amount ]
  end

  test "what is due today for a person: timed ones in time order, untimed after, done today kept" do
    @household.todos.create!(person: people(:buzzsaw), title: "Later", due_at: Time.utc(2026, 10, 14, 18))
    @household.todos.create!(person: people(:buzzsaw), title: "Sooner", due_at: Time.utc(2026, 10, 14, 16))
    @household.todos.create!(person: people(:buzzsaw), title: "Someday")
    @household.todos.create!(person: people(:buzzsaw), title: "Tomorrow", due_on: Date.new(2026, 10, 15))
    @household.todos.create!(person: people(:buzzsaw), title: "Overdue", due_on: Date.new(2026, 10, 10))
    done = @household.todos.create!(person: people(:buzzsaw), title: "Done one", due_on: Date.new(2026, 10, 14))
    done.complete!
    assert_equal [ "Sooner", "Later", "Overdue", "Someday", "Done one" ], @household.todos_today_for(people(:buzzsaw)).map(&:title)
  end
end
