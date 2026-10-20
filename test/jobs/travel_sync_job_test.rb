require "test_helper"
require "turbo/broadcastable/test_helper"

# Travel times from Home Assistant's Waze service (plan: Integrations; second gap review: every
# 10 min within ~2 h of leave-by, hourly otherwise, cached by destination). Synced events with a
# location get a drive time; the leave-by follows.
class TravelSyncJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @household.update!(home_address: "1 Home St", travel_region: "us")
    @source = @household.calendar_sources.create!(name: "Family", url: "https://calendar.example.com/f.ics")
    @soon = @household.events.create!(calendar_source: @source, uid: "soon", title: "Dentist", location: "9 Clinic Rd", starts_at: Time.utc(2026, 10, 14, 16, 30), ends_at: Time.utc(2026, 10, 14, 17))
    @later = @household.events.create!(calendar_source: @source, uid: "later", title: "Dinner", location: "Nonna's", starts_at: Time.utc(2026, 10, 14, 23), ends_at: Time.utc(2026, 10, 15))
    @tomorrow = @household.events.create!(calendar_source: @source, uid: "tmrw", title: "Swim", location: "Pool", starts_at: Time.utc(2026, 10, 15, 16), ends_at: Time.utc(2026, 10, 15, 17))
    @nowhere = @household.events.create!(calendar_source: @source, uid: "nowhere", title: "Call", starts_at: Time.utc(2026, 10, 14, 18), ends_at: Time.utc(2026, 10, 14, 19))
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    @calls = []
    HomeAssistant.transport = lambda do |request|
      @calls << request[:body]
      minutes = { "9 Clinic Rd" => 17.4, "Nonna's" => 31.0, "Pool" => 9.0 }.fetch(request[:body]["destination"].to_s.strip.then { |d| d.casecmp?("9 clinic rd") ? "9 Clinic Rd" : d })
      [ 200, { "service_response" => { "routes" => [ { "distance" => 12.3, "duration" => minutes, "name" => "via Main St" } ] } } ]
    end
  end

  teardown { HomeAssistant.reset! }

  test "today's upcoming synced events with a location get a drive time from home; the screens hear once" do
    streams = capture_turbo_stream_broadcasts(@household) { TravelSyncJob.perform_now }
    assert_equal 1, streams.size
    assert_includes streams.first["targets"].split(","), "today-hero"
    assert_equal [ 17, 31 ], [ @soon.reload.travel_minutes, @later.reload.travel_minutes ]
    assert_nil @tomorrow.reload.travel_minutes, "tomorrow is not checked yet"
    assert_nil @nowhere.reload.travel_minutes
    assert_equal Time.utc(2026, 10, 14, 16, 13), @soon.leave_by
    assert_equal({ "origin" => "1 Home St", "destination" => "9 Clinic Rd", "region" => "us" }, @calls.first.slice("origin", "destination", "region"))
  end

  test "two events at the same place share one route lookup" do
    @household.events.create!(calendar_source: @source, uid: "soon2", title: "Cleaning", location: " 9 clinic rd ", starts_at: Time.utc(2026, 10, 14, 17, 30), ends_at: Time.utc(2026, 10, 14, 18))
    TravelSyncJob.perform_now
    assert_equal 1, @calls.count { |c| c["destination"].to_s.strip.casecmp?("9 Clinic Rd") }
    assert_equal 17, @household.events.find_by(uid: "soon2").travel_minutes
  end

  test "near events refresh every 10 minutes, far ones hourly" do
    TravelSyncJob.perform_now
    @calls.clear
    travel 5.minutes
    TravelSyncJob.perform_now
    assert_empty @calls, "nothing is due five minutes later"
    travel 6.minutes
    TravelSyncJob.perform_now
    assert_equal [ "9 Clinic Rd" ], @calls.map { |c| c["destination"] }, "only the event within two hours of leaving"
    travel 55.minutes
    @calls.clear
    TravelSyncJob.perform_now
    assert_includes @calls.map { |c| c["destination"] }, "Nonna's"
  end

  test "nothing happens without a home address or without Home Assistant; a failing route leaves the event alone" do
    @household.update!(home_address: nil)
    TravelSyncJob.perform_now
    assert_nil @soon.reload.travel_minutes
    @household.update!(home_address: "1 Home St")
    HomeAssistant.transport = ->(_r) { [ 500, { "message" => "no route" } ] }
    TravelSyncJob.perform_now
    assert_nil @soon.reload.travel_minutes
  end

  test "the job is on the schedule every 10 minutes" do
    entry = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]["travel_sync"]
    assert_equal "TravelSyncJob", entry["class"]
    assert_match(/10 minutes/, entry["schedule"])
  end
end
