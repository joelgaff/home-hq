require "application_system_test_case"

# Live sync (plan: milestone 3): a write made elsewhere (another screen, a phone, a job) reaches
# this screen over the cable as a "pieces" broadcast, and the screen fetches just those pieces.
class LiveSyncTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen(name: "Kitchen")
    find(".rail-item[data-go=tasks]").click
    assert_selector "#view-tasks.is-active"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 10
  end

  test "a chore completed elsewhere shows as done here, with the Today card following" do
    row = "#chores .ch[data-chore='#{chores(:homework).id}']"
    assert_selector row
    assert_no_selector "#{row}.is-done"

    # Elsewhere: outside any request, so the broadcast goes out at once with no origin.
    chores(:homework).complete!

    assert_selector "#{row}.is-done", wait: 10
    assert_selector "#today-chores .h-ring .num", text: "2/4", visible: :all, wait: 5
    assert_no_selector "#toasts .toast:not(.toast--tip)"  # the writer gets the Undo toast, not this screen
  end

  test "a household setting changed elsewhere reloads the page" do
    assert_selector "#stage[data-shell-clock-value='12']", visible: :all
    households(:primary).update!(clock_format: "24")
    assert_selector "#stage[data-shell-clock-value='24']", visible: :all, wait: 10
    assert_selector "#view-tasks.is-active", wait: 10
  end

  test "a grocery added elsewhere appears on the list here" do
    find(".rail-item[data-go=shopping]").click
    assert_selector "#view-shopping.is-active"
    households(:primary).add_grocery("Lemons")
    assert_selector "#shopping .s-row", text: /lemons/i, wait: 10
  end
end
