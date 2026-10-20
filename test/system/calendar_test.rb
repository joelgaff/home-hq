require "application_system_test_case"

# Calendar in the browser: navigation re-renders the frame without a page load, the grid
# auto-scrolls to now, and tapping an event opens the sheet.
class CalendarTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
    find(".rail-item[data-go=calendar]").click
    assert_selector "#view-calendar.is-active"
  end

  test "next and mode links swap the frame in place" do
    assert_selector "#calendar .cal-title .label", text: /october 2026 · today/i
    execute_script("window.__mark = 1")
    find("#calendar [data-nav='1']").click
    assert_selector "#calendar .cal-title .label", text: /tomorrow/i
    assert_selector "#calendar [data-today]:not(.is-hidden)"
    find("#calendar [data-mode=week]").click
    assert_selector "#calendar .week .wk-col", count: 7
    assert_equal 1, evaluate_script("window.__mark"), "the page must not have reloaded"
  end

  test "the time grid starts scrolled near now" do
    top = evaluate_script("document.querySelector('#calendar .grid-scroll').scrollTop")
    assert_in_delta 669 - 170, top, 40
  end

  test "tapping an event opens its sheet, the scrim closes it" do
    find("#calendar .ev", text: /piano/i).click
    assert_selector "#sheetLayer.is-open .sheet.sheet--event .evs-band h2", text: "Piano lesson"
    assert_selector "#sheetLayer .evs-leave", text: /leave by 3:33 PM/i
    find("#sheetLayer .sheet-scrim").click(x: -500, y: 0)
    assert_no_selector "#sheetLayer.is-open"
  end

  test "Escape closes the sheet" do
    find("#calendar .ev", text: /piano/i).click
    assert_selector "#sheetLayer.is-open"
    find("body").send_keys(:escape)
    assert_no_selector "#sheetLayer.is-open"
  end
end

# Milestone 4 in the browser: the sheet's people override, the directions QR code, and the
# calendar following an event that arrived from a feed elsewhere.
class CalendarSyncBrowserTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    households(:primary).update!(demo: false)  # no demo tip toast over the sheet
    show_on_screen
    find(".rail-item[data-go=calendar]").click
    assert_selector "#view-calendar.is-active"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 10
  end

  test "tapping a person chip on the sheet changes who the event is for, and the calendar follows" do
    find("#calendar .ev", text: /Piano lesson/).click
    assert_selector "#sheet .evs-band h2", text: "Piano lesson"
    assert_selector "#sheet .evs-people button.is-on", count: 1
    find("#sheet .evs-people button", text: "Claudia").click
    assert_selector "#sheet .evs-people button.is-on", count: 2, wait: 5
    assert_selector "#sheet .evs-people button", text: /back to the calendar/i
    assert_selector "#calendar .ev", text: /Piano lesson/, wait: 5
    assert_equal %w[Claudia Skidmark], events(:piano).reload.attending_people.map(&:name).sort
  end

  test "the location row opens a QR code inside the sheet, and back returns to the event" do
    find("#calendar .ev", text: /Piano lesson/).click
    find("#sheet a.evs-row", text: /Ms. Park/).click
    assert_selector "#sheet .evs-qr svg", wait: 5
    assert_selector "#sheet .evs-directions b", text: "Ms. Park's Studio"
    click_on "← Back to the event"
    assert_selector "#sheet .evs-leave b", text: /Leave by/, wait: 5
  end

  test "an event synced elsewhere appears on the calendar here" do
    source = households(:primary).calendar_sources.create!(name: "Family", url: "https://calendar.example.com/f.ics")
    Pieces.batch(origin: nil) do
      households(:primary).events.create!(calendar_source: source, uid: "x", title: "Flu shots", starts_at: Time.utc(2026, 10, 14, 19), ends_at: Time.utc(2026, 10, 14, 19, 30))
    end
    assert_selector "#calendar .ev", text: /Flu shots/, wait: 10
  end
end
