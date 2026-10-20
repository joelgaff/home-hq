require "test_helper"
require "turbo/broadcastable/test_helper"

# The garage-open banner (plan: milestone 6; ui-spec §1.9): fifteen minutes after the garage
# opens, if it is still open, the screens get a banner saying for how long and who is how far
# away; "Leave open" quiets it until the door closes and opens again.
class GarageOpenCheckJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @garage = devices(:garage)
    @garage.deviceable.update!(state: "closed")
    Current.household = @household
  end

  teardown { Current.reset }

  test "opening the garage schedules a check; still open fifteen minutes later means a banner" do
    assert_enqueued_with(job: GarageOpenCheckJob) { @garage.deviceable.update!(state: "open") }
    people(:wes).update!(home: false, eta_minutes: 12)
    travel 15.minutes
    streams = capture_turbo_stream_broadcasts(@household) { GarageOpenCheckJob.perform_now(@garage.id, @garage.deviceable.updated_at) }
    alert = @household.home_alerts.last
    assert_equal "garage_open", alert.kind
    assert_match(/open for 15 min/i, alert.message)
    assert_match(/Wes is 12 min away/, alert.message)
    assert streams.any? { |s| s["action"] == "alert" && s["kind"] == "garage" }
  end

  test "a garage closed again, or one left open on purpose, gets no banner" do
    @garage.deviceable.update!(state: "open")
    opened_at = @garage.deviceable.updated_at
    @garage.deviceable.update!(state: "closed")
    GarageOpenCheckJob.perform_now(@garage.id, opened_at)
    assert_equal 0, @household.home_alerts.count

    @garage.deviceable.update!(state: "open")
    opened_at = @garage.deviceable.updated_at
    @household.home_alerts.create!(kind: "garage_open", device: @garage, acknowledged_at: Time.current, created_at: opened_at + 15.minutes)
    GarageOpenCheckJob.perform_now(@garage.id, opened_at)
    assert_equal 1, @household.home_alerts.count, "quiet after Leave open"
  end
end
