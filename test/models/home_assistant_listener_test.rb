require "test_helper"
require "rake"

# The live link to the hub (plan: Integrations: Rails ↔ HA WebSocket API): one long-running
# process authenticates, subscribes to state changes, reads every state once, and applies each
# change to our rows. Tests hand it a fake connection.
class HomeAssistantListenerTest < ActiveSupport::TestCase
  # A scripted connection: `messages` are what the hub sends (in order), `sent` what we sent.
  class FakeConnection
    attr_reader :sent
    def initialize(messages) = (@messages, @sent, @closed = messages.dup, [], false)
    def send(json) = @sent << JSON.parse(json)
    def read = @messages.shift&.to_json
    def close = @closed = true
    def closed? = @closed
  end

  setup do
    @household = households(:primary)
    @light = devices(:island)
    @light.update!(entity_id: "light.island")
    @light.deviceable.update!(on: false, level: 100)
    HomeAssistant.configure(url: "http://ha.test:8123", token: "secret-token")
    HomeAssistant.transport = ->(_r) { [ 200, {} ] }
    HomeAssistant::StateSync.forget_unit!
  end

  teardown { HomeAssistant.reset! }

  test "authenticates, subscribes, reads the states once and applies each change until the hub hangs up" do
    conn = FakeConnection.new([
      { "type" => "auth_required", "ha_version" => "2026.1" },
      { "type" => "auth_ok" },
      { "id" => 2, "type" => "result", "success" => true, "result" => [ { "entity_id" => "light.island", "state" => "on", "attributes" => { "brightness" => 255 } } ] },
      { "id" => 1, "type" => "result", "success" => true },
      { "id" => 1, "type" => "event", "event" => { "event_type" => "state_changed", "data" => { "entity_id" => "light.island", "new_state" => { "entity_id" => "light.island", "state" => "off", "attributes" => {} } } } },
      { "id" => 1, "type" => "event", "event" => { "event_type" => "state_changed", "data" => { "entity_id" => "light.island", "new_state" => { "entity_id" => "light.island", "state" => "on", "attributes" => { "brightness" => 128 } } } } }
    ])
    HomeAssistant::Listener.new(connection: conn).session
    assert_equal [ "auth", "subscribe_events", "get_states" ], conn.sent.map { |m| m["type"] }
    assert_equal "secret-token", conn.sent[0]["access_token"]
    assert_equal "state_changed", conn.sent[1]["event_type"]
    assert_equal [ true, 50 ], [ @light.reload.on?, @light.level ]
  end

  test "a refused login stops the session with the reason" do
    conn = FakeConnection.new([ { "type" => "auth_required" }, { "type" => "auth_invalid", "message" => "Invalid access token" } ])
    error = assert_raises(HomeAssistant::Error) { HomeAssistant::Listener.new(connection: conn).session }
    assert_match(/Invalid access token/, error.message)
  end

  test "the websocket address comes from the hub's url" do
    assert_equal "ws://ha.test:8123/api/websocket", HomeAssistant::Listener.socket_url
    HomeAssistant.configure(url: "https://ha.example.com/", token: "t")
    assert_equal "wss://ha.example.com/api/websocket", HomeAssistant::Listener.socket_url
  end

  test "the listen task exists for the bridge process" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("home_assistant:listen")
    assert Rake::Task.task_defined?("home_assistant:listen")
  end
end
