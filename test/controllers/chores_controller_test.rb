require "test_helper"

# The Chores view (docs/ui-spec.md §1.3) at 3:18 PM on Wed 14 Oct 2026 (After school).
class ChoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    travel_to Time.utc(2026, 10, 14, 15, 18)
  end

  test "the dashboard page carries the chores frame" do
    get root_path
    assert_select "#view-tasks turbo-frame#chores .tasks", 1
  end

  test "header: Right now, the routine, the toggle and progress" do
    get chores_path
    assert_select ".t-head .t-title .label", "Right now · 11 AM – 5 PM"
    assert_select ".t-head h1", "After school"
    assert_select ".t-head .seg a", 3
    assert_select ".t-head .seg a.is-on", "After school"
    assert_select ".t-progress .num", /1\s*\/8/
    assert_select ".t-progress .t-bar i[style*='12.5']", 1
  end

  test "a lane per person plus Anyone, with stars for kids and N of M for adults" do
    get chores_path
    assert_select ".ch-lanes .ch-lane", 5
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-head .ch-stars .num", "42"
    assert_select ".ch-lane[data-lane='#{people(:wes).id}'] .ch-head .ch-sub", "0 of 1"
    assert_select ".ch-lane[data-lane='#{people(:claudia).id}'] .ch-head .ch-sub", "Nothing"
    assert_select ".ch-lane[data-lane=any] .ch-head .ch-sub", "Up for grabs"
    assert_select ".ch-lane[data-lane=any] .ch-head b", "Anyone"
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-ring .num", "1/4"
    assert_select ".ch-lane[data-lane='#{people(:claudia).id}'] .ch-ring .num", "–"
  end

  test "rows: not done first, overdue label, star counts, the check animation shell" do
    get chores_path
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch" do |rows|
      assert_equal [ "Make bed", "Homework", "Pack soccer bag", "Unpack lunchbox" ], rows.map { |r| r.at_css(".ch-text b").text }
      assert rows.first["class"].include?("is-overdue"), "the morning leftover comes first, overdue"
      assert rows.last["class"].include?("is-done")
    end
    assert_select ".ch-lane[data-lane='#{people(:wes).id}'] .ch.is-overdue .ch-late", "Overdue"
    assert_select ".ch[data-chore='#{chores(:homework).id}'] small", /2/
    assert_select ".ch[data-chore='#{chores(:homework).id}'] .ch-check svg", 1
    assert_select ".ch-lane[data-lane='#{people(:claudia).id}'] .ch-none", "Nothing this afternoon"
  end

  test "a completed Anyone chore says who did it; a kid's week strip shows hits and misses" do
    chores(:dishwasher).complete!(by: people(:skidmark))
    get chores_path
    assert_select ".ch[data-chore='#{chores(:dishwasher).id}'] small", /2 · Skidmark/
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-week-row span", 7
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-week-row span.is-today", 1
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-week-row span.is-miss", 2
    assert_select ".ch-lane[data-lane='#{people(:wes).id}'] .ch-week", 0
  end

  test "a lane with everything done says All done" do
    chores(:recycling).update!(routine: routines(:after_school))
    chores(:recycling).complete!
    get chores_path
    assert_select ".ch-lane[data-lane='#{people(:wes).id}'].is-complete .ch-alldone", /All done/
    assert_select ".ch-lane[data-lane='#{people(:wes).id}'] .ch-ring .num", "✓"
  end

  test "another routine can be shown; it is not Right now" do
    get chores_path(routine: routines(:evening).id)
    assert_select ".t-head h1", "Evening"
    assert_select ".t-head .t-title .label", "5 – 10 PM"
    assert_select ".ch[data-chore='#{chores(:set_table).id}']", 1
  end

  test "completing a chore re-renders the view and the Today card, with an Undo toast" do
    assert_difference -> { people(:buzzsaw).stars }, 2 do
      post chore_completions_path(chores(:homework)), as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[action=replace][target=chores] .ch[data-chore='#{chores(:homework).id}'].is-done", 1
    assert_select "turbo-stream[action=replace][target=today-chores]", 1
    assert_select "turbo-stream[action=update][target=toasts] .toast" do
      assert_select ".toast-msg", /Homework.*done · \+2★ Buzzsaw/m
      assert_select "form[action=?][method=post] input[name=_method][value=delete]", chore_completion_path(ChoreCompletion.last)
      assert_select ".toast-undo", /Undo/
    end
  end

  test "the chosen routine survives a completion" do
    post chore_completions_path(chores(:set_table)), params: { routine: routines(:evening).id }, as: :turbo_stream
    assert_select "turbo-stream[target=chores] .t-head h1", "Evening"
  end

  test "finishing the whole routine celebrates without an Undo" do
    routines(:after_school).chores.where.not(id: chores(:homework).id).each { |c| c.complete!(by: people(:buzzsaw)) }
    post chore_completions_path(chores(:homework)), as: :turbo_stream
    assert_select "turbo-stream[target=toasts] .toast-msg", /After school routine complete!.*Everyone crushed it/m
    assert_select "turbo-stream[target=toasts] .toast-undo", 0
  end

  test "an Anyone chore asks who did it, then credits them" do
    get new_chore_completion_path(chores(:dishwasher))
    assert_select ".sheet-h", "Who did it?"
    assert_select ".add-who--big .who-btn", 4
    assert_select "form[action^=?]", chore_completions_path(chores(:dishwasher)), 4
    post chore_completions_path(chores(:dishwasher)), params: { person_id: people(:skidmark).id }, as: :turbo_stream
    assert_equal "Skidmark", chores(:dishwasher).done_by.name
    assert_equal 59, people(:skidmark).stars
  end

  test "undoing (or un-completing) deletes the completion and its stars, no toast" do
    completion = chores(:homework).complete!
    delete chore_completion_path(completion), as: :turbo_stream
    assert_response :success
    assert_not chores(:homework).reload.done?
    assert_equal 42, people(:buzzsaw).stars
    assert_select "turbo-stream[action=replace][target=chores]", 1
    assert_select "turbo-stream[action=update][target=toasts]" do |streams|
      assert_select streams, ".toast", 0
    end
  end

  # ---------------------------------------------------------------- schedules (plan: Gap review answers)
  test "the routine toggle lists only the routines that run today" do
    routines(:evening).update!(weekdays: Routine.weekdays_mask(%w[sat sun]))
    get chores_path
    assert_select ".t-head .seg a", 2
    assert_select ".t-head .seg a", text: "Evening", count: 0
  end

  test "an undone morning chore is carried into the afternoon lane as overdue" do
    get chores_path
    assert_select ".ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch:first-child.is-overdue .ch-text b", "Make bed"
    assert_select ".t-progress .num", /1\s*\/8/
  end

  test "the vacation pause empties the lanes and says so" do
    households(:primary).update!(chores_paused_until: Date.new(2026, 10, 20))
    get chores_path
    assert_select ".ch-paused", /paused until October 20/i
    assert_select ".ch-lanes .ch", 0
  end
end
