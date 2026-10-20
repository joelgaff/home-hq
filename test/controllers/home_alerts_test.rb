require "test_helper"
require "turbo/broadcastable/test_helper"

# Alerts from the house (plan: milestone 6; ui-spec §1.9): Home Assistant automations call a
# webhook with a shared secret; the alert is kept, every screen hears it as an "alert" stream
# action (the takeover or banner), and acknowledging it from the frame is logged.
class HomeAlertsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    HomeAssistant.webhook_secret = "hook-secret"
    @household = households(:primary)
    @camera = @household.cameras.create!(name: "Doorbell", entity_id: "camera.doorbell")
  end

  teardown { HomeAssistant.reset! }

  test "the webhook needs the secret" do
    post hooks_home_assistant_path, params: { kind: "doorbell" }, as: :json
    assert_response :unauthorized
    post hooks_home_assistant_path, params: { kind: "doorbell" }, headers: { "X-Hook-Secret" => "wrong" }, as: :json
    assert_response :unauthorized
    assert_equal 0, HomeAlert.count
  end

  test "a doorbell press becomes an alert, broadcast to the screens with its camera" do
    streams = capture_turbo_stream_broadcasts(@household) do
      post hooks_home_assistant_path, params: { kind: "doorbell", camera: "camera.doorbell" }, headers: { "X-Hook-Secret" => "hook-secret" }, as: :json
    end
    assert_response :created
    alert = @household.home_alerts.last
    assert_equal [ "doorbell", @camera ], [ alert.kind, alert.camera ]
    stream = streams.find { |s| s["action"] == "alert" }
    assert stream, "an alert stream action"
    assert_equal [ "doorbell", camera_path(@camera), alert.id.to_s ], [ stream["kind"], stream["camera-url"], stream["alert-id"] ]
  end

  test "package, leak and garage-open alerts carry their text; unknown kinds are refused" do
    post hooks_home_assistant_path, params: { kind: "package", camera: "camera.doorbell", message: "Front porch" }, headers: { "X-Hook-Secret" => "hook-secret" }, as: :json
    assert_response :created
    assert_equal "Front porch", @household.home_alerts.last.message
    post hooks_home_assistant_path, params: { kind: "leak", message: "Laundry room sensor" }, headers: { "X-Hook-Secret" => "hook-secret" }, as: :json
    assert_response :created
    post hooks_home_assistant_path, params: { kind: "disco" }, headers: { "X-Hook-Secret" => "hook-secret" }, as: :json
    assert_response :unprocessable_entity
  end

  test "acknowledging from the frame is kept and logged" do
    alert = @household.home_alerts.create!(kind: "leak", message: "Laundry room")
    show_on_screen(name: "Kitchen")
    patch acknowledge_home_alert_path(alert), as: :turbo_stream
    assert_response :success
    assert alert.reload.acknowledged_at.present?
    entry = @household.audit_entries.last
    assert_equal [ "alert.acknowledged", "Kitchen" ], [ entry.action, entry.actor_name ]
  end

  test "the page carries the takeover templates for the frame only" do
    show_on_screen
    get root_path
    assert_select "#takeover[data-controller=alerts]", 1
    reset!
    sign_in_as users(:owner)
    get root_path
    assert_select "#takeover", 0
  end
end
