require "test_helper"
require "turbo/broadcastable/test_helper"

# Live sync between screens (plan: milestone 3). A write broadcasts one "pieces" stream action to
# the household naming the pieces it changed; every screen but the one that wrote fetches those
# pieces from /pieces, rendered for itself (its layout, its session). Spike rules: the smallest
# stable ids, coalesced per request, never the whole page.
class LiveSyncTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  def pieces_broadcast(&block)
    streams = capture_turbo_stream_broadcasts(households(:primary), &block)
    assert_equal 1, streams.size, "one coalesced broadcast per request, got #{streams.size}"
    streams.first
  end

  test "the dashboard page subscribes to the household's stream, and a screen to its own as well" do
    get root_path
    assert_select "turbo-cable-stream-source[signed-stream-name]", 2
  end

  test "completing a chore broadcasts the chores pieces, tagged with the writer's page token" do
    stream = pieces_broadcast do
      post chore_completions_path(chores(:homework)), headers: { "X-Page-Token" => "abc123" }, as: :turbo_stream
    end
    assert_equal "pieces", stream["action"]
    assert_equal %w[chores today-chores], stream["targets"].split(",").sort
    assert_equal "abc123", stream["origin"]
  end

  test "adding, checking and clearing groceries broadcast the shopping pieces" do
    stream = pieces_broadcast { post grocery_items_path, params: { name: "Lemons" }, as: :turbo_stream }
    assert_equal %w[shopping shopping-side today-shopping], stream["targets"].split(",").sort
    stream = pieces_broadcast { patch check_grocery_item_path(grocery_items(:bananas)), as: :turbo_stream }
    assert_equal %w[shopping shopping-side today-shopping], stream["targets"].split(",").sort
  end

  test "device, scene, thermostat and media writes broadcast the control pieces" do
    stream = pieces_broadcast { patch device_path(devices(:island)), params: { on: true, level: 100 }, as: :turbo_stream }
    assert_equal %w[control-rooms control-sum today-status], stream["targets"].split(",").sort
    stream = pieces_broadcast { post scene_activations_path, params: { scene_id: scenes(:movie).id }, as: :turbo_stream }
    assert_includes stream["targets"].split(","), "control-scenes"
    assert_includes stream["targets"].split(","), "control-rooms"
    stream = pieces_broadcast { patch thermostat_path, params: { delta: 0.5 }, as: :turbo_stream }
    assert_equal %w[control-climate control-sum today-status], stream["targets"].split(",").sort
    stream = pieces_broadcast { patch media_player_path, as: :turbo_stream }
    assert_equal %w[control-media control-sum], stream["targets"].split(",").sort
  end

  test "household settings baked into every page tell the screens to reload; the chores pause moves the chores" do
    household = households(:primary)
    %w[temperature_unit=f clock_format=24 time_zone=America/Los_Angeles week_start=sunday].each do |change|
      attr, value = change.split("=")
      streams = capture_turbo_stream_broadcasts(household) { household.update!(attr => value) }
      assert_equal [ "reload" ], streams.map { |t| t["action"] }, "changing #{attr}"
    end
    streams = capture_turbo_stream_broadcasts(household) { household.update!(chores_paused_until: Date.new(2026, 10, 20)) }
    assert_equal [ "pieces" ], streams.map { |t| t["action"] }
    assert_equal %w[chores today-chores], streams.first["targets"].split(",").sort
    streams = capture_turbo_stream_broadcasts(household) { household.update!(name: "The Gaffs") }
    assert_empty streams, "a name change moves nothing on the screens"
  end

  test "a read broadcasts nothing" do
    streams = capture_turbo_stream_broadcasts(households(:primary)) { get chores_path }
    assert_empty streams
  end

  test "/pieces renders the asked-for pieces as replaces, in the asker's context" do
    get pieces_path(ids: %w[chores today-chores shopping nonsense], routine: routines(:evening).id, store: stores(:costco).id, drawer: 1), as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action=replace][target=chores] turbo-frame#chores .t-title h1", "Evening"
    assert_select "turbo-stream[action=replace][target=today-chores] turbo-frame#today-chores", 1
    assert_select "turbo-stream[action=replace][target=shopping] turbo-frame#shopping[data-store='#{stores(:costco).id}'][data-drawer='1']", 1
    assert_select "turbo-stream", 3
  end
end
