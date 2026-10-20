require "test_helper"

# Calendar sources (plan: Calendars, pluggable sources): an ICS feed becomes Event rows for a
# rolling window, recurrence expanded, and each event's people follow the rules: a manual
# override, then names in the title, then the calendar's assigned people (none = everyone).
class CalendarSourceTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @source = @household.calendar_sources.create!(name: "Family", url: "https://calendar.example.com/family.ics")
    @ics = file_fixture("family.ics").read
  end

  def synced
    @source.sync!(body: @ics)
    @source.events.includes(attendees: :person).by_start
  end

  test "an ICS feed becomes events inside the window, skipping cancelled and long-gone ones" do
    events = synced
    assert_equal 1, events.where(uid: "dentist@test").count
    assert_equal 0, events.where(uid: "cancelled@test").count
    assert_equal 0, events.where(uid: "old@test").count
    dentist = events.find_by(uid: "dentist@test")
    assert_equal [ "Buzzsaw dentist", Time.utc(2026, 10, 15, 17), Time.utc(2026, 10, 15, 17, 45), false, "Bright Smiles Dental", "Bring the insurance card." ],
      [ dentist.title, dentist.starts_at, dentist.ends_at, dentist.all_day, dentist.location, dentist.notes ]
    assert @source.reload.synced_at.present?
    assert_nil @source.last_error
  end

  test "all-day events run from midnight to an exclusive midnight end" do
    trip = synced.find_by(title: "Grandma's house")
    assert trip.all_day
    assert_equal [ Time.utc(2026, 10, 17), Time.utc(2026, 10, 19) ], [ trip.starts_at, trip.ends_at ]
    assert_equal 2, trip.span_days
  end

  test "a weekly rule is expanded for the window, honouring an exception and a moved occurrence" do
    swims = synced.where("title LIKE 'Buzzsaw + Skidmark swim%'").to_a
    starts = swims.map { |e| e.starts_at.in_time_zone("America/Los_Angeles").strftime("%m-%d %H:%M") }
    assert_equal [ "10-12 16:00", "10-19 16:30", "11-02 16:00", "11-09 16:00", "11-16 16:00", "11-23 16:00", "11-30 16:00", "12-07 16:00" ], starts
    assert_equal "Buzzsaw + Skidmark swim (late)", swims[1].title
  end

  test "a timed event with no end lasts an hour" do
    karate = synced.find_by(uid: "karate@test")
    assert_equal karate.starts_at + 1.hour, karate.ends_at
  end

  test "people come from names in the title, nicknames included, else from the calendar's people, else everyone" do
    people(:skidmark).update!(nicknames: "Skid, Skiddy")
    events = synced
    assert_equal [ "Buzzsaw" ], events.find_by(uid: "dentist@test").attending_people.map(&:name)
    assert_equal %w[Buzzsaw Skidmark], events.find_by(title: "Buzzsaw + Skidmark swim").attending_people.map(&:name).sort
    assert_equal [ "Skidmark" ], events.find_by(uid: "karate@test").attending_people.map(&:name)
    trip = events.find_by(title: "Grandma's house")
    assert trip.family?, "no name in the title and no assigned people: everyone"

    @source.people = [ people(:claudia) ]
    trip = synced.find_by(title: "Grandma's house")
    assert_equal [ "Claudia" ], trip.attending_people.map(&:name)
    assert_equal [ "Buzzsaw" ], synced.find_by(uid: "dentist@test").attending_people.map(&:name), "a name in the title still wins"
  end

  test "a manual people override survives a re-sync, and events gone from the feed are removed" do
    dentist = synced.find_by(uid: "dentist@test")
    dentist.override_people!([ people(:wes), people(:buzzsaw) ])
    assert_equal %w[Buzzsaw Wes], synced.find_by(uid: "dentist@test").attending_people.map(&:name).sort

    @source.sync!(body: @ics.sub(/BEGIN:VEVENT\nUID:karate@test.*?END:VEVENT\n/m, ""))
    assert_nil @source.events.find_by(uid: "karate@test")
    assert_equal 1, @source.events.where(uid: "dentist@test").count, "syncing twice does not duplicate"
  end

  test "a bad feed records the error and keeps the last good events" do
    synced
    @source.sync!(body: "this is not a calendar")
    assert_match(/calendar/i, @source.reload.last_error)
    assert @source.events.exists?(uid: "dentist@test")
  end

  test "a Google share link is refused with a pointer to the secret iCal address" do
    source = @household.calendar_sources.build(name: "Shared", url: "https://calendar.google.com/calendar/u/0?cid=YWJj")
    assert_not source.valid?
    assert_match(/Secret address in iCal format/, source.errors[:url].join)
  end

  test "a Google public address that answers 404 explains the secret address" do
    CalendarSources::Ics.fetcher = ->(_url) { raise CalendarSources::Ics::NotFound }
    source = @household.calendar_sources.create!(name: "G", url: "https://calendar.google.com/calendar/ical/abc%40gmail.com/public/basic.ics")
    assert_not source.sync!
    assert_match(/not public.*Secret address in iCal format/, source.reload.last_error)
  ensure
    CalendarSources::Ics.fetcher = nil
  end

  test "a web page instead of a calendar says so" do
    assert_not @source.sync!(body: "<!DOCTYPE html><html><body>Sign in</body></html>")
    assert_equal "this address returned a web page, not a calendar feed", @source.reload.last_error
  end
end
