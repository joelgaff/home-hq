require "test_helper"
require "turbo/broadcastable/test_helper"

# The recurring sync (plan: Integrations, calendars: every 5 minutes): due sources are fetched
# and their events upserted; the screens hear about it once, as the calendar pieces.
class CalendarSyncJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @source = @household.calendar_sources.create!(name: "Family", url: "https://calendar.example.com/family.ics")
    CalendarSources::Ics.fetcher = ->(_url) { file_fixture("family.ics").read }
  end

  teardown { CalendarSources::Ics.fetcher = nil }

  test "due sources are synced and the screens get one pieces broadcast" do
    streams = capture_turbo_stream_broadcasts(@household) { CalendarSyncJob.perform_now }
    assert_equal 1, streams.size
    assert_equal "pieces", streams.first["action"]
    assert_equal %w[calendar today-agenda today-hero today-lanes], streams.first["targets"].split(",").sort
    assert @source.reload.synced_at.present?
    assert @source.events.exists?(uid: "dentist@test")
  end

  test "a source synced a moment ago, or disabled, is left alone" do
    @source.update!(synced_at: 1.minute.ago)
    assert_no_turbo_stream_broadcasts(@household) { CalendarSyncJob.perform_now }
    assert_equal 0, @source.events.count

    @source.update!(synced_at: nil, enabled: false)
    CalendarSyncJob.perform_now
    assert_equal 0, @source.events.count
  end

  test "the job is on the production schedule" do
    entry = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]["calendar_sync"]
    assert_equal "CalendarSyncJob", entry["class"]
    assert_match(/5 minutes/, entry["schedule"])
  end
end
