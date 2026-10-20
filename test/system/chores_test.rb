require "application_system_test_case"

# Chores in the browser: tap to complete with the check animation and an Undo toast, Anyone
# chores ask who did it, done chores un-complete on tap.
class ChoresTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
    find(".rail-item[data-go=tasks]").click
    assert_selector "#view-tasks.is-active"
  end

  test "completing a chore animates, awards stars, toasts, and Undo takes it back" do
    row = "#chores .ch[data-chore='#{chores(:homework).id}']"
    find(row).click
    assert_selector "#{row}.is-checking"
    assert_selector "#{row}.is-done", wait: 5
    assert_selector "#chores .ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-stars .num", text: "44"
    assert_selector "#toasts .toast.is-in .toast-msg", text: /homework.*done · \+2★ buzzsaw/i
    assert_selector "#today-chores .h-ring b", text: "2/4", visible: :all

    find("#toasts .toast-undo").click
    assert_no_selector "#{row}.is-done", wait: 5
    assert_selector "#chores .ch-lane[data-lane='#{people(:buzzsaw).id}'] .ch-stars .num", text: "42"
    assert_no_selector "#toasts .toast:not(.toast--tip)"  # the demo tip does not count
  end

  test "an Anyone chore asks who did it" do
    find("#chores .ch[data-chore='#{chores(:dishwasher).id}']").click
    assert_selector "#sheetLayer.is-open .sheet-h", text: /who did it\?/i
    find("#sheetLayer .who-btn", text: /skidmark/i).click
    assert_no_selector "#sheetLayer.is-open"
    assert_selector "#chores .ch[data-chore='#{chores(:dishwasher).id}'].is-done small", text: /skidmark/i
    assert_selector "#chores .ch-lane[data-lane='#{people(:skidmark).id}'] .ch-stars .num", text: "59"
  end

  test "tapping a done chore un-completes it without a toast" do
    row = "#chores .ch[data-chore='#{chores(:unpack_lunchbox).id}']"
    assert_selector "#{row}.is-done"
    find(row).click
    assert_no_selector "#{row}.is-done", wait: 5
    assert_no_selector "#toasts .toast:not(.toast--tip)"  # the demo tip does not count
  end
end
