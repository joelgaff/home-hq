require "test_helper"
require "turbo/broadcastable/test_helper"

# The settings pages (plan: milestone 3): the household, people, routines, chores, stores with
# their aisle orders, categories and the catalogue, all with full CRUD and up/down ordering.
# Adults only: a screen is refused, nobody signed in is sent to log in.
class SettingsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  # ---------------------------------------------------------------- access
  test "settings are for signed-in people, not screens" do
    get settings_path
    assert_redirected_to new_session_path
    show_on_screen
    get settings_path
    assert_response :forbidden
  end

  test "the settings page links every area" do
    sign_in_as users(:owner)
    get settings_path
    assert_response :success
    %w[people routines chores stores categories catalog_items].each do |area|
      assert_select "a[href=?]", send("settings_#{area}_path"), minimum: 1
    end
    assert_select "a[href=?]", screens_path
    assert_select "form[action=?]", settings_path
  end

  # ---------------------------------------------------------------- household
  test "the household's name, zone, units, clock, week start and chores pause are editable" do
    sign_in_as users(:owner)
    patch settings_path, params: { household: { name: "The Gaffs", time_zone: "America/Los_Angeles", temperature_unit: "f", clock_format: "24", week_start: "sunday", chores_paused_until: "2026-10-20" } }
    assert_redirected_to settings_path
    h = households(:primary).reload
    assert_equal [ "The Gaffs", "America/Los_Angeles", "f", "24", "sunday", Date.new(2026, 10, 20) ], [ h.name, h.time_zone, h.temperature_unit, h.clock_format, h.week_start, h.chores_paused_until ]
    patch settings_path, params: { household: { temperature_unit: "k" } }
    assert_response :unprocessable_entity
    patch settings_path, params: { household: { week_start: "friday" } }
    assert_response :unprocessable_entity
    patch settings_path, params: { household: { time_zone: "Mars/Olympus_Mons" } }
    assert_response :unprocessable_entity
    patch settings_path, params: { household: { chores_paused_until: "" } }
    assert_nil households(:primary).reload.chores_paused_until
  end

test "the time zone select shows the household's zone selected and offers IANA names" do
  sign_in_as users(:owner)
  households(:primary).update!(time_zone: "America/Los_Angeles")
  get settings_path
  assert_select "select[name='household[time_zone]'] option[selected][value='America/Los_Angeles']", 1
  assert_select "select[name='household[time_zone]'] option[value='Pacific Time (US & Canada)']", 0
end

  # ---------------------------------------------------------------- people
  test "people: list, add with an ink that suits the colour, set the login email, reorder, remove" do
    sign_in_as users(:owner)
    get settings_people_path
    assert_select ".settings-list li", 4
    assert_select ".settings-list li:first-child", /Wes/

    post settings_people_path, params: { person: { name: "Biscuit", color: "#FFD60A", kid: "1" } }
    biscuit = households(:primary).people.find_by!(name: "Biscuit")
    assert_redirected_to settings_people_path
    assert_equal "#111111", biscuit.ink, "dark ink on a light colour"
    assert_equal 5, biscuit.position
    assert biscuit.kid?

    patch settings_person_path(people(:wes)), params: { person: { name: "Joel", color: "#1D3F9F", email: " Owner@Example.com " } }
    assert_equal [ "Joel", "#FFFFFF", "owner@example.com", users(:owner) ], [ people(:wes).reload.name, people(:wes).ink, people(:wes).email, people(:wes).user ]
    get settings_people_path
    assert_select ".settings-list li:first-child", /owner@example.com/
    assert_select "select[name='person[user_id]']", 0

    patch move_settings_person_path(people(:skidmark)), params: { direction: "up" }
    assert_equal %w[Joel Claudia Skidmark Buzzsaw Biscuit], households(:primary).people.reload.map(&:name)
    patch move_settings_person_path(people(:skidmark)), params: { direction: "down" }
    assert_equal %w[Joel Claudia Buzzsaw Skidmark Biscuit], households(:primary).people.reload.map(&:name)

    delete settings_person_path(biscuit)
    assert_nil Person.find_by(id: biscuit.id)
  end

  # ---------------------------------------------------------------- routines and chores
  test "routines: add with weekdays and an automatic range label, edit, reorder, remove" do
    sign_in_as users(:owner)
    post settings_routines_path, params: { routine: { name: "Weekend morning", from_hour: 8, to_hour: 12, weekdays: %w[sat sun] } }
    r = households(:primary).routines.find_by!(name: "Weekend morning")
    assert_equal "8 AM – 12 PM", r.range_label
    assert_equal %w[sat sun], r.weekday_names
    assert_equal 4, r.position

    patch settings_routine_path(r), params: { routine: { range_label: "8 – noon", weekdays: [] } }
    assert_equal [ "8 – noon", [] ], [ r.reload.range_label, r.weekday_names ]

    patch move_settings_routine_path(r), params: { direction: "up" }
    assert_equal [ "Morning", "After school", "Weekend morning", "Evening" ], households(:primary).routines.reload.map(&:name)

    delete settings_routine_path(r)
    assert_nil Routine.find_by(id: r.id)
  end

  test "chores: add for a person or Anyone with weekdays, edit, reorder within the lane, remove; the screens hear about it" do
    sign_in_as users(:owner)
    streams = capture_turbo_stream_broadcasts(households(:primary)) do
      post settings_chores_path, params: { chore: { title: "Piano practice", emoji: "🎹", stars: 2, routine_id: routines(:after_school).id, person_id: people(:skidmark).id, weekdays: %w[mon wed] } }
    end
    c = households(:primary).chores.find_by!(title: "Piano practice")
    assert_equal [ %w[mon wed], 2, people(:skidmark) ], [ c.weekday_names, c.position, c.person ]
    assert_equal %w[chores today-chores], streams.first["targets"].split(",").sort

    post settings_chores_path, params: { chore: { title: "Sweep", emoji: "🧹", stars: 1, routine_id: routines(:evening).id, person_id: "" } }
    assert households(:primary).chores.find_by!(title: "Sweep").anyone?

    patch move_settings_chore_path(c), params: { direction: "up" }
    assert_equal [ "Piano practice", "Read for 20 min" ], routines(:after_school).chores.where(person: people(:skidmark)).in_order.map(&:title)

    patch settings_chore_path(c), params: { chore: { title: "Piano", weekdays: [] } }
    assert_equal [ "Piano", [] ], [ c.reload.title, c.weekday_names ]

    delete settings_chore_path(c)
    assert_nil Chore.find_by(id: c.id)
  end

  # ---------------------------------------------------------------- shopping
  test "stores: add, reorder, and move a category up its aisle order" do
    sign_in_as users(:owner)
    post settings_stores_path, params: { store: { name: "Trader Joe's" } }
    tj = households(:primary).stores.find_by!(name: "Trader Joe's")
    assert_equal 3, tj.position
    patch move_settings_store_path(tj), params: { direction: "up" }
    assert_equal [ "FreshCo", "Trader Joe's", "Costco" ], households(:primary).stores.reload.map(&:name)

    get settings_store_path(stores(:costco))
    assert_select ".settings-list li:first-child", /Household/
    patch move_settings_store_aisle_path(stores(:costco), categories(:produce)), params: { direction: "up" }
    assert_equal %w[Household Pantry Snacks Dairy\ &\ Eggs Meat\ &\ Fish Produce Frozen Bakery], stores(:costco).reload.aisle_order.map(&:name)

    # A store with no aisle order yet starts from the household's order.
    patch move_settings_store_aisle_path(stores(:grocer), categories(:bakery)), params: { direction: "up" }
    assert_equal %w[Bakery Produce], stores(:grocer).reload.aisle_order.first(2).map(&:name)

    delete settings_store_path(tj)
    assert_nil Store.find_by(id: tj.id)
  end

  test "categories and the catalogue: add, edit, reorder, remove" do
    sign_in_as users(:owner)
    post settings_categories_path, params: { category: { name: "Deli" } }
    deli = households(:primary).categories.find_by!(name: "Deli")
    patch move_settings_category_path(deli), params: { direction: "up" }
    assert_equal %w[Deli Household], households(:primary).categories.reload.last(2).map(&:name)

    post settings_catalog_items_path, params: { catalog_item: { name: "Hummus", category_id: deli.id, usual: "1" } }
    hummus = households(:primary).catalog_items.find_by!(name: "Hummus")
    assert hummus.usual?
    assert_includes households(:primary).usuals, hummus
    patch settings_catalog_item_path(hummus), params: { catalog_item: { usual: "0" } }
    assert_not hummus.reload.usual?

    delete settings_category_path(deli)
    assert_nil hummus.reload.category, "the item stays, under Other"
    delete settings_catalog_item_path(hummus)
    assert_nil CatalogItem.find_by(id: hummus.id)
  end

  test "the settings pages render" do
    sign_in_as users(:owner)
    [ settings_path, settings_people_path, new_settings_person_path, edit_settings_person_path(people(:wes)),
      settings_routines_path, new_settings_routine_path, settings_chores_path, new_settings_chore_path,
      edit_settings_chore_path(chores(:homework)), settings_stores_path, settings_store_path(stores(:costco)),
      settings_categories_path, settings_catalog_items_path ].each do |path|
      get path
      assert_response :success, path
      assert_select "main.page", 1
    end
  end
end
