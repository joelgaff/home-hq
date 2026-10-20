require "test_helper"

# Right after a fresh start the household has no people, routines or chores (plan: milestone 3
# "start fresh"); the page, the Chores view and its pieces still render, with an empty state.
class EmptyHouseholdTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    households(:primary).fresh_start!
  end

  test "the frame renders an empty household" do
    show_on_screen
    get root_path
    assert_response :success
    assert_select "#chores .ch-empty", text: /no routines yet/i
    assert_select "#today-chores .h-empty", text: /no chores yet/i
  end

  # Every GET route, as the frame, an adult and a kid, with and without stores: nothing may raise.
  PATHS = lambda do |h|
    store = h.stores.first
    [ "/", "/today", "/today?part=hero", "/today?part=chores", "/today?part=agenda", "/today?part=lanes", "/today?part=presence",
      "/calendar", "/calendar?mode=week", "/calendar?mode=day", "/calendar?mode=month", "/calendar?mode=month&date=2026-11-01",
      "/events", "/chores", "/shopping", "/shopping?drawer=cleared", "/shopping?drawer=catalog", "/shopping?drawer=usuals",
      (store ? "/shopping?store=#{store.id}" : nil), "/control", "/devices", "/people",
      (h.people.first ? "/people?person=#{h.people.first.id}" : nil),
      "/pieces?pieces=#{Pieces::REGISTRY.keys.join(',')}" ].compact
  end
  SETTINGS = %w[/settings /settings/people /settings/people/new /settings/routines /settings/routines/new /settings/chores
    /settings/chores/new /settings/categories /settings/categories/new /settings/catalog_items /settings/catalog_items/new
    /settings/stores /settings/stores/new /screens /screens/new].freeze

  def nothing_raises(paths)
    paths.each do |p|
      get p
      assert_includes [ 200, 302 ], response.status, "#{p} answered #{response.status}"
    end
  end

  test "every route answers for the frame, with and without stores" do
    h = households(:primary)
    show_on_screen
    nothing_raises PATHS.call(h)
    h.stores.create!(name: "Costco")
    nothing_raises PATHS.call(h)
  end

  test "every route answers for an adult, before and after adding themselves and a store" do
    h = households(:primary)
    sign_in_as users(:owner)
    nothing_raises PATHS.call(h) + SETTINGS
    h.stores.create!(name: "Costco")
    person = h.people.create!(name: "Joel", color: "#2D5BFF", email: users(:owner).email)
    nothing_raises PATHS.call(h) + SETTINGS + [ "/settings/stores/#{h.stores.first.id}", "/settings/people/#{person.id}/edit" ]
  end

  test "every route answers for a kid with no chores yet" do
    h = households(:primary)
    h.people.create!(name: "Robin", color: "#00A36C", kid: true, email: users(:owner).email)
    sign_in_as users(:owner)
    nothing_raises PATHS.call(h)
    get settings_path
    assert_response :forbidden
  end

  test "a cleared home (no rooms, devices, thermostat, speaker or cameras) still renders everywhere" do
    h = households(:primary)
    h.clear_home!
    show_on_screen
    nothing_raises [ "/", "/control", "/devices", "/devices?kind=security", "/pieces?pieces=#{Pieces::REGISTRY.keys.join(',')}", "/today?part=status" ]
    get root_path
    assert_select "#control-sum .sum", 2, "lights and security stay; climate and media need their things"
  end

  test "a person's app renders an empty household, and the Chores view on its own" do
    sign_in_as users(:owner)
    get root_path
    assert_response :success
    get chores_path
    assert_response :success
    assert_select "#chores .ch-empty"
    get pieces_path(pieces: "chores,today-chores"), as: :turbo_stream
    assert_response :success
  end

  test "clearing the samples removes the demo home, photos and weather but keeps what is real" do
    h = households(:primary)
    real_photo = h.photos.create!(image_key: "immich:abc", immich_id: "abc", taken_on: Date.new(2020, 1, 1))
    real_weather = h.weather_reports.create!(high: 60, low: 50, fetched_at: Time.current, source: "open_meteo")
    demo_weather = h.weather_reports.create!(high: 18, low: 9, fetched_at: 1.hour.ago)
    h.clear_samples!
    assert_equal [ 0, 0, 0, 0 ], [ h.rooms.count, h.devices.count, h.scenes.count, h.cameras.count ]
    assert_nil h.reload.thermostat
    assert_equal [ real_photo ], h.photos.to_a
    assert_equal [ real_weather ], h.weather_reports.to_a
    assert_not WeatherReport.exists?(demo_weather.id)

    real_weather.destroy
    show_on_screen
    nothing_raises PATHS.call(h) + [ "/today?part=status", "/devices?kind=security" ]
  end

  test "a fresh start clears the samples too" do
    assert_equal 0, households(:primary).devices.count
    assert_equal 0, households(:primary).photos.where(immich_id: nil).count
  end
end
