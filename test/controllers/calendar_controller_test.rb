require "test_helper"

# The Calendar view (docs/ui-spec.md §1.2) at 3:18 PM on Wed 14 Oct 2026, as the frame shows it.
class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    show_on_screen
    travel_to Time.utc(2026, 10, 14, 15, 18)
  end

  test "the dashboard page carries the calendar frame in Today mode" do
    get root_path
    assert_select "#view-calendar turbo-frame#calendar .cal.cal--day", 1
  end

  test "header: title, kicker, nav links, hidden Today button, mode toggle, hidden add button" do
    get calendar_path
    assert_select ".cal-head .cal-title .serif", /Wednesday\s*14/
    assert_select ".cal-head .cal-title .label", "October 2026 · Today"
    assert_select ".cal-head a[data-nav=-1][href=?]", calendar_path(mode: "day", date: "2026-10-13")
    assert_select ".cal-head a[data-nav='1'][href=?]", calendar_path(mode: "day", date: "2026-10-15")
    assert_select ".cal-head [data-today].is-hidden", 1
    assert_select ".cal-head .seg a", 4
    assert_select ".cal-head .seg a.is-on", "Today"
    assert_select ".cal-head .fab.is-hidden", 1
  end

  test "another day shows the Today button and the relative kicker" do
    get calendar_path(mode: "day", date: "2026-10-15")
    assert_select ".cal-title .label", "October 2026 · Tomorrow"
    assert_select ".cal-head [data-today][href=?]", calendar_path(mode: "day", date: "2026-10-14")
    assert_select ".cal-head [data-today].is-hidden", 0
  end

  test "Today mode: a lane per person, family events full width, the now-line, all-day row" do
    get calendar_path
    assert_select ".cal-day .lanes .lane", 4
    assert_select ".lanes .lane:nth-child(4) .ev", 1 do
      assert_select ".ev-title", "Piano lesson"
      assert_select ".ev-meta", /3:45 – 4:30 PM · .*Leave 3:33/
      assert_select ".ev-travel[style*='height:14.4px']", 1
    end
    assert_select ".lane-fam .ev.is-family .ev-title", "Dinner at Nonna's"
    assert_select ".lane-fam .ev.is-family .dots i", 4
    assert_select ".lanes .lane:nth-child(3) .ev.is-past .ev-title", "Dentist"
    assert_select ".now-line[style*='top:669']", 1
    assert_select ".now-line .num", "3:18"
    assert_select ".allday .ad[style*='grid-column:4 / span 1']", "Pajama Day at school"
    assert_select ".hours .hr span", minimum: 18
    assert_select ".hours .hr span", text: "Noon"
  end

  test "Today mode: a shared event shows who else is on it; a short one is compact" do
    events(:dentist).update!(ends_at: Time.utc(2026, 10, 14, 12, 40))
    get calendar_path
    assert_select ".lanes .lane:nth-child(3) .ev.is-short", 1 do
      assert_select ".ev-title", "Dentist"
      assert_select ".ev-with .dots i", 1
    end
  end

  test "Today mode: a multi-day all-day event says which day it is" do
    get calendar_path(mode: "day", date: "2026-10-16")
    assert_select ".allday .ad.ad--cont", /Wes in Montréal\s*Day 2 of 3/
  end

  test "Today mode: an empty day says so" do
    get calendar_path(mode: "day", date: "2026-10-20")
    assert_select ".cal-empty", /Nothing on the calendar/
  end

  test "Today mode: overlapping events collapse into a more block" do
    3.times do |i|
      e = households(:primary).events.create!(title: "Clash #{i}", starts_at: Time.utc(2026, 10, 14, 9, i * 10), ends_at: Time.utc(2026, 10, 14, 10, 30))
      e.attendees.create!(person: people(:wes))
    end
    get calendar_path
    assert_select ".lanes .lane:nth-child(1) .ev--more[data-more]", /\+2\s*more/
  end

  test "3-day mode: day headers, today shaded, all-day bars spanning days, now-line on today only" do
    get calendar_path(mode: "3day", date: "2026-10-14")
    assert_select ".cal-3 .lanes-head .day-head", 3
    assert_select ".lanes-head .day-head.is-today b", "Today"
    assert_select ".lanes-head .day-head:nth-child(3) b", "Tomorrow"
    assert_select ".lanes--3 .lane.is-today", 1
    assert_select ".allday-grid--3 .ad[style*='grid-column:2 / 4']", /Wes in Montréal/
    assert_select ".now-line.now-line--0", 1
    assert_select ".cal-title .serif", /Wed 14\s*–\s*Fri 16/
    assert_select ".cal-head a[data-nav='1'][href=?]", calendar_path(mode: "3day", date: "2026-10-17")
  end

  test "Week mode: seven rolling days with chips, timed rows, +N more and Free" do
    get calendar_path(mode: "week", date: "2026-10-14")
    assert_select ".week .wk-col", 7
    assert_select ".wk-col.is-today .wk-head b", "Wed"
    assert_select ".wk-col:nth-child(1) .wk-ad", "Pajama Day at school"
    assert_select ".wk-col:nth-child(1) .wk-ev", 4
    assert_select ".wk-col:nth-child(1) .wk-ev.is-past .wk-n", "Dentist"
    assert_select ".wk-col:nth-child(5) .wk-free", "Free"
    assert_select ".wk-col[data-day='2026-10-16'] a[href=?]", calendar_path(mode: "day", date: "2026-10-16")
    assert_select ".cal-title .label", "Next 7 days"
  end

  test "Month mode: Monday-start six weeks, today inverted, out-of-month faded, dots" do
    get calendar_path(mode: "month", date: "2026-10-01")
    assert_select ".month .mo-dow .label", 7
    assert_select ".month .mo-dow .label:first-child", "Mon"
    assert_select ".mo-grid .mo-cell", 42
    assert_select ".mo-grid .mo-cell:first-child .num", "28"
    assert_select ".mo-grid .mo-cell.is-out", minimum: 3
    assert_select ".mo-cell.is-today .num", "14"
    assert_select ".mo-cell.is-today .mo-dots i", 5
    assert_select ".mo-cell.is-today .mo-dots em", 0
    assert_select ".mo-cell.is-today[href=?]", calendar_path(mode: "day", date: "2026-10-14")
    assert_select ".cal-title .serif", "October"
    assert_select ".cal-head a[data-nav='1'][href=?]", calendar_path(mode: "month", date: "2026-11-01")
  end

  test "Month mode starts the week on Sunday when the household's week does" do
    households(:primary).update!(week_start: "sunday")
    get calendar_path(mode: "month", date: "2026-10-01")
    assert_select ".month .mo-dow .label:first-child", "Sun"
    assert_select ".month .mo-dow .label:last-child", "Sat"
    assert_select ".mo-grid .mo-cell:first-child .num", "27"
  end

  test "an unknown mode or date falls back to today" do
    get calendar_path(mode: "bogus", date: "nope")
    assert_response :success
    assert_select ".cal.cal--day", 1
  end

  test "the event sheet: band, leave by, location, people, notes" do
    get event_path(events(:piano))
    assert_select ".sheet-body[data-sheet-class='sheet--event']"
    assert_select ".evs-band .label", "Today · October 14"
    assert_select ".evs-band h2", "Piano lesson"
    assert_select ".evs-time", "3:45 – 4:30 PM"
    assert_select ".evs-leave b", "Leave by 3:33 PM"
    assert_select ".evs-leave span", "12 min drive in current traffic"
    assert_select ".evs-row b", "Ms. Park's Studio"
    assert_select "a.evs-row span", "Tap for directions on your phone"
    assert_select ".evs-people .chip", text: /Skidmark/
    assert_select ".evs-notes", "“Bring the blue theory book.”"
  end

  test "the event sheet for a family all-day event lists everyone and says All day" do
    get event_path(events(:pajama_day))
    assert_select ".evs-time", "All day"
    get event_path(events(:dinner))
    assert_select ".evs-people button[name='person_ids[]'].is-on", 4
    assert_select ".evs-people button[name=everyone].is-on", 1
  end

  test "the overlapping sheet lists the collapsed events" do
    get events_path(ids: [ events(:piano).id, events(:soccer).id ].join(","))
    assert_select ".sheet-h", "2 more events"
    assert_select ".more-row[data-ev]", 2
  end

  test "a calendar feed that stopped syncing is named in the header" do
    source = households(:primary).calendar_sources.create!(name: "School", url: "https://calendar.example.com/s.ics", synced_at: Time.utc(2026, 10, 14, 15, 10))
    get calendar_path
    assert_select ".cal-stale", 0
    source.update!(synced_at: Time.utc(2026, 10, 14, 13, 40))
    get calendar_path
    assert_select ".cal-stale", "School not updated since 1:40 PM"
    source.update!(synced_at: nil, last_error: "the feed answered 404")
    get calendar_path
    assert_select ".cal-stale", "School can’t be read"
  end
end
