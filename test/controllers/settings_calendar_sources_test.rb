require "test_helper"

# Settings → Calendars (plan: Calendars): add an ICS feed, assign it to people (none = everyone),
# sync it now, see its status, disable or remove it; nicknames on people feed the title rule.
class SettingsCalendarSourcesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    sign_in_as users(:owner)
    CalendarSources::Ics.fetcher = ->(_url) { file_fixture("family.ics").read }
  end

  teardown { CalendarSources::Ics.fetcher = nil }

  test "add a feed for two people, sync it now, see its status, then disable and remove it" do
    get settings_path
    assert_select "a[href=?]", settings_calendar_sources_path
    get settings_calendar_sources_path
    assert_select "p", text: /no calendars yet/i

    post settings_calendar_sources_path, params: { calendar_source: { name: "Kids", url: "webcal://calendar.example.com/kids.ics", refresh_minutes: 10,
      person_ids: [ people(:buzzsaw).id, people(:skidmark).id ] } }
    source = households(:primary).calendar_sources.last
    assert_redirected_to settings_calendar_sources_path
    assert_equal [ "https://calendar.example.com/kids.ics", 10, %w[Buzzsaw Skidmark] ], [ source.url, source.refresh_minutes, source.people.map(&:name).sort ]
    follow_redirect!
    assert_select "li", text: /Kids.*Buzzsaw, Skidmark.*not synced yet/mi

    post sync_settings_calendar_source_path(source)
    assert_redirected_to settings_calendar_sources_path
    follow_redirect!
    assert_select "li", text: /Kids.*\d+ events.*synced/mi
    assert source.events.exists?(uid: "dentist@test")

    patch settings_calendar_source_path(source), params: { calendar_source: { enabled: "0", person_ids: [] } }
    source.reload
    assert_not source.enabled?
    assert_equal [], source.people
    get settings_calendar_sources_path
    assert_select "li", text: /Kids.*Everyone.*off/mi

    delete settings_calendar_source_path(source)
    assert_nil CalendarSource.find_by(id: source.id)
    assert_equal 0, Event.where(uid: "dentist@test").count, "its events go with it"
  end

  test "a feed that cannot be read keeps its error on the list" do
    CalendarSources::Ics.fetcher = ->(_url) { raise CalendarSources::Ics::Invalid, "the feed answered 404" }
    source = households(:primary).calendar_sources.create!(name: "Broken", url: "https://calendar.example.com/x.ics")
    post sync_settings_calendar_source_path(source)
    follow_redirect!
    assert_select ".page-flash--alert", text: /404/
    assert_select "li", text: /Broken.*404/m
  end

  test "a bad address is refused" do
    post settings_calendar_sources_path, params: { calendar_source: { name: "x", url: "" } }
    assert_response :unprocessable_entity
  end

  test "people take nicknames" do
    patch settings_person_path(people(:skidmark)), params: { person: { nicknames: "Skid, Skiddy" } }
    assert_equal "Skid, Skiddy", people(:skidmark).reload.nicknames
    get edit_settings_person_path(people(:skidmark))
    assert_select "input[name='person[nicknames]'][value='Skid, Skiddy']", 1
  end
end
