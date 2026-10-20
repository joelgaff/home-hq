require "test_helper"

# Chores (ui-spec §1.3): routines by hour, lanes per person + Anyone, completions per day (so the
# daily reset is automatic), stars as a ledger so Undo is a deleted entry.
class ChoreTest < ActiveSupport::TestCase
  setup do
    @household = households(:primary)
    travel_to Time.utc(2026, 10, 14, 15, 18) # a Wednesday afternoon
  end

  test "the current routine comes from the hour" do
    assert_equal "After school", @household.current_routine.name
    assert_equal "Morning", @household.current_routine(at: Time.utc(2026, 10, 14, 7)).name
    assert_equal "Evening", @household.current_routine(at: Time.utc(2026, 10, 14, 23, 30)).name
  end

  test "a chore is done today when it has a completion dated today" do
    assert chores(:unpack_lunchbox).done?
    assert_not chores(:homework).done?
    assert_not chores(:make_bed).done?, "yesterday's completion does not count today"
  end

  test "chores in a lane list not-done first, then overdue first" do
    titles = @household.chores_for(routines(:after_school), person: people(:buzzsaw)).map(&:title)
    assert_equal [ "Make bed", "Homework", "Pack soccer bag", "Unpack lunchbox" ], titles, "the undone morning chore is carried in, overdue, first"
    assert_equal [ "Take out recycling" ], @household.chores_for(routines(:after_school), person: people(:wes)).map(&:title)
    assert_equal [ "Empty dishwasher", "Water the plants" ], @household.chores_for(routines(:after_school), person: nil).map(&:title)
  end

  test "overdue chores sort before the rest of the undone ones" do
    chores(:homework).update!(position: 0)
    chores(:soccer_bag).update!(routine: routines(:morning))
    assert_equal [ "Make bed", "Pack soccer bag", "Homework", "Unpack lunchbox" ],
      @household.chores_for(routines(:after_school), person: people(:buzzsaw)).map(&:title)
  end

  # ---------------------------------------------------------------- schedules (plan: Gap review answers)
  test "a chore is due every day unless it names weekdays" do
    assert chores(:homework).due_on?(Date.new(2026, 10, 14))
    chores(:homework).update!(weekdays: Chore.weekdays_mask(%w[mon wed]))
    assert chores(:homework).due_on?(Date.new(2026, 10, 14)), "Wednesday"
    assert_not chores(:homework).due_on?(Date.new(2026, 10, 15)), "Thursday"
    assert_equal %w[mon wed], chores(:homework).weekday_names
  end

  test "a chore on other days is not in today's lane or progress" do
    chores(:homework).update!(weekdays: Chore.weekdays_mask(%w[tue thu]))
    assert_not_includes @household.chores_for(routines(:after_school), person: people(:buzzsaw)).map(&:title), "Homework"
    assert_equal [ 1, 7 ], @household.routine_progress(routines(:after_school))
  end

  test "a weekend routine is not active on a Wednesday, nor current, nor are its chores due" do
    routines(:evening).update!(weekdays: Routine.weekdays_mask(%w[sat sun]))
    assert_not routines(:evening).active_on?(Date.new(2026, 10, 14))
    assert routines(:evening).active_on?(Date.new(2026, 10, 17))
    assert_equal %w[Morning After\ school], @household.active_routines.map(&:name)
    assert_equal "After school", @household.current_routine(at: Time.utc(2026, 10, 14, 23, 30)).name
    assert_not chores(:set_table).due_on?(Date.new(2026, 10, 14))
  end

  test "the vacation pause makes nothing due until the date" do
    @household.update!(chores_paused_until: Date.new(2026, 10, 20))
    assert @household.chores_paused?
    assert_not chores(:homework).due_on?(Date.new(2026, 10, 14))
    assert chores(:homework).due_on?(Date.new(2026, 10, 21))
    assert_empty @household.chores_for(routines(:after_school), person: people(:buzzsaw))
    assert_equal [ 0, 0 ], @household.routine_progress(routines(:after_school))
  end

  test "overdue means due in an earlier routine today and not done" do
    assert chores(:recycling).overdue?, "a morning chore at 3:18 PM"
    assert_not chores(:homework).overdue?, "the current routine is not over"
    assert_not chores(:recycling).overdue?(at: Time.utc(2026, 10, 14, 9)), "during its routine"
    chores(:recycling).complete!
    assert_not chores(:recycling).reload.overdue?
  end

  test "overdue chores are carried into the current routine's lane, first, and nowhere else" do
    assert_equal [ "Take out recycling" ], @household.chores_for(routines(:after_school), person: people(:wes)).map(&:title)
    assert_equal [ "Take out recycling" ], @household.chores_for(routines(:morning), person: people(:wes)).map(&:title)
    assert_empty @household.chores_for(routines(:evening), person: people(:wes))
    assert_equal [ 1, 8 ], @household.routine_progress(routines(:after_school)), "carried chores count"
  end

  test "completing a kid's chore awards the stars to the kid" do
    completion = chores(:homework).complete!
    assert chores(:homework).reload.done?
    assert_equal 44, people(:buzzsaw).stars
    assert_equal completion, people(:buzzsaw).star_entries.last.chore_completion
  end

  test "completing an Anyone chore awards the stars to whoever did it" do
    chores(:dishwasher).complete!(by: people(:skidmark))
    assert_equal 59, people(:skidmark).stars
    assert_equal "Skidmark", chores(:dishwasher).reload.done_by.name
  end

  test "an adult's chore earns nobody stars" do
    chores(:recycling).complete!
    assert_equal 42, people(:buzzsaw).stars
    assert_equal 57, people(:skidmark).stars
  end

  test "undoing a completion takes the stars back" do
    completion = chores(:homework).complete!
    completion.undo!
    assert_not chores(:homework).reload.done?
    assert_equal 42, people(:buzzsaw).stars
  end

  test "stars from a completion go to the chore owner even when someone else helped" do
    chores(:read).complete!(by: people(:buzzsaw))
    assert_equal 59, people(:skidmark).stars
    assert_equal 42, people(:buzzsaw).stars
  end

  test "the routine's progress counts done over total, carried overdue chores included" do
    assert_equal [ 1, 8 ], @household.routine_progress(routines(:after_school))
  end

  test "the week strip marks past days hit or miss, today and the future apart" do
    strip = people(:buzzsaw).week_strip
    # Mon 12 (no routine chores done) miss, Tue 13 hit (bed + table both done? the after-school
    # chores had none) -> hit only if every chore due was done.
    assert_equal %w[miss miss today future future future future], strip.map(&:last)
    assert_equal %w[M T W T F S S], strip.map(&:first)
  end

  test "the week strip counts only the chores due each day; paused days and days with nothing due are off" do
    # Buzzsaw's after-school chores move to Wednesdays: on Tuesday only bed and table were due, both done.
    %i[homework soccer_bag unpack_lunchbox].each { |c| chores(c).update!(weekday_names: %w[wed]) }
    assert_equal %w[miss hit today future future future future], people(:buzzsaw).week_strip.map(&:last)
    @household.update!(chores_paused_until: Date.new(2026, 10, 12))
    assert_equal %w[off hit today future future future future], people(:buzzsaw).reload.week_strip.map(&:last)
    assert_equal %w[off off today future future future future], people(:claudia).week_strip.map(&:last), "no chores at all"
  end

  test "the week strip starts on Sunday when the household's week does" do
    @household.update!(week_start: "sunday")
    strip = people(:buzzsaw).week_strip
    assert_equal %w[S M T W T F S], strip.map(&:first)
    assert_equal %w[miss miss miss today future future future], strip.map(&:last)
  end
end
