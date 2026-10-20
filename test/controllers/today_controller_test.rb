require "test_helper"

# The Today view (docs/ui-spec.md §1.1), rendered from fixtures at 3:18 PM on Wed 14 Oct 2026.
class TodayControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    travel_to Time.utc(2026, 10, 14, 15, 18)
  end

  test "the view sits inside the dashboard page" do
    get root_path
    assert_select "#view-home .home", 1
    assert_select "#view-home turbo-frame#today-hero", 1
  end

  test "clock: time, AM/PM, weekday and date" do
    get today_path
    assert_select "#today-clock .h-time", text: /3:18\s*PM/
    assert_select "#today-clock .h-date b", "Wednesday"
    assert_select "#today-clock .h-date", /October 14/
    assert_select "#today-clock[data-go=calendar]"
  end

  test "weather: now, highs, the advice and seven hourly cells" do
    get today_path
    assert_select "#today-weather .h-wx-temp", "15°"
    assert_select "#today-weather .h-wx-meta b", "Overcast"
    assert_select "#today-weather .h-wx-meta span", /H 17°\s+L 8°/
    assert_select "#today-weather .h-wx-say", /Rain from 4 PM\.\s*Pack a rain jacket for soccer\./
    assert_select "#today-weather .h-hr", 7
    assert_select "#today-weather .h-hr:first-child .h-hr-l", "Now"
    assert_select "#today-weather .h-hr.is-wet", 4
  end

  test "weather from a source that stopped updating says how old it is (plan: Offline and stale data)" do
    report = weather_reports(:today)
    get today_path
    assert_select "#today-weather .h-wx-stale", 0, "the demo's weather has no source to go stale"
    report.update!(source: "open_meteo", fetched_at: Time.utc(2026, 10, 14, 13, 5))
    get today_path
    assert_select "#today-weather .h-wx-stale", "as of 1:05 PM"
    report.update!(fetched_at: Time.utc(2026, 10, 14, 15, 0))
    get today_path
    assert_select "#today-weather .h-wx-stale", 0
  end

  test "presence: avatar, name, Home / ETA / status" do
    get today_path
    assert_select "#today-presence .h-who", 2  # adults only (plan: gap review)
    assert_select "#today-presence .h-who:not(.is-home) .avatar--away", 2
    assert_select "#today-presence .h-who small b", "ETA 12 min"
    assert_select "#today-presence .h-who small", "At the office"
  end

  test "hero: next up by leave-by, with countdown and leave pill" do
    get today_path
    assert_select "#today-hero .h-hero[data-ev]" do
      assert_select ".label", "Next up · Skidmark"
      assert_select ".h-hero-title", "Piano lesson"
      assert_select ".h-hero-meta", "3:45 – 4:30 PM · Ms. Park's Studio"
      assert_select ".h-hero-count", /27\s*min/
      assert_select ".pill.pill--soon", /Leave in 15 min/
    end
  end

  test "hero: Leave now when the leave-by has passed, time instead of minutes far out" do
    travel_to Time.utc(2026, 10, 14, 15, 35)
    get today_path
    assert_select "#today-hero .pill--alert", /Leave now/

    travel_to Time.utc(2026, 10, 14, 7, 0)
    get today_path
    assert_select "#today-hero .h-hero-title", "Dentist"
    assert_select "#today-hero .h-hero-count", /12:00\s*PM/
  end

  test "hero: everyone, with dots, for a family event" do
    travel_to Time.utc(2026, 10, 14, 17, 0)
    get today_path
    assert_select "#today-hero .label", "Next up · Everyone"
    assert_select "#today-hero .dots i", 4
  end

  test "hero: nothing left today points at tomorrow" do
    travel_to Time.utc(2026, 10, 14, 20, 0)
    get today_path
    assert_select "#today-hero .h-hero--empty[data-go=calendar]" do
      assert_select ".h-hero-title", /Nothing else scheduled/
      assert_select ".h-hero-meta", /Tomorrow starts with\s+Gym\s+at 7:00 AM/
    end
  end

  test "lanes: remaining timed events per person, Now for a current one, free otherwise" do
    get today_path
    assert_select "#today-lanes .h-lane", 4
    assert_select "#today-lanes .h-lane:nth-child(3)" do
      assert_select ".h-lane-head b", "Buzzsaw"
      assert_select ".h-ev .h-ev-n" do |names|
        assert_equal [ "Soccer practice", "Dinner at Nonna's" ], names.map(&:text)
      end
    end
    assert_select "#today-lanes .h-lane:nth-child(4) .h-ev:first-of-type .h-ev-t", "3:45"

    travel_to Time.utc(2026, 10, 14, 16, 0)
    get today_path
    assert_select "#today-lanes .h-lane:nth-child(4) .h-ev.is-now .h-ev-t", "Now"
  end

  test "lanes: more than three remaining shows +N more" do
    4.times do |i|
      e = households(:primary).events.create!(title: "Thing #{i}", starts_at: Time.utc(2026, 10, 14, 19 + i, 45), ends_at: Time.utc(2026, 10, 14, 20 + i))
      e.attendees.create!(person: people(:wes))
    end
    get today_path
    assert_select "#today-lanes .h-lane:nth-child(1) .h-ev", 3
    assert_select "#today-lanes .h-lane:nth-child(1) .h-more[data-go=calendar]", "+2 more"
  end

  test "chores card: a ring per person with chores in the current routine, plus Anyone" do
    get today_path
    assert_select "#today-chores .label", "Chores · After school"
    assert_select "#today-chores .h-ring", 4
    assert_select "#today-chores .h-ring span" do |names|
      assert_equal [ "Wes", "Buzzsaw", "Skidmark", "Anyone" ], names.map(&:text)
    end
    assert_select "#today-chores .h-ring b" do |counts|
      assert_equal [ "0/1", "1/4", "0/1", "0/2" ], counts.map(&:text), "Buzzsaw carries the undone morning chore"
    end
    chores(:read).complete!
    get today_path
    assert_select "#today-chores .h-ring.is-done b", "✓"
  end

  test "shopping card: open count and the last three items" do
    get today_path
    assert_select "#today-shopping .h-stat .num", "6"
    assert_select "#today-shopping .h-recent li", 3
  end

  test "home card: lights, security and the inside temperature" do
    get today_path
    assert_select "#today-status .h-st-row:nth-child(2)", /3\s*lights on/
    assert_select "#today-status .h-st-row:nth-child(3)", "All locked"
    assert_select "#today-status .h-st-row:nth-child(3).is-warn", 0
    assert_select "#today-status .h-st-row:nth-child(4)", /20\.5°\s*inside/

    devices(:garage).apply(state: "open")
    get today_path
    assert_select "#today-status .h-st-row.is-warn", "Garage open"
  end

  test "the photo tile carries the slideshow pool" do
    get today_path
    assert_select "#today-photo [data-controller=slideshow][data-slideshow-interval-value='12000'][data-slideshow-caption-outlet-selector-value='#today-photo-cap']"
  end

  test "one part can be re-rendered on its own as a Turbo Frame" do
    get today_path(part: "hero"), headers: { "Turbo-Frame" => "today-hero" }
    assert_response :success
    assert_select "turbo-frame#today-hero", 1
    assert_select "turbo-frame#today-lanes", 0
  end
end
