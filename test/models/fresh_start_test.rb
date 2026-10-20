require "test_helper"

# Moving from the demo data to the real household (plan: milestone 3 "start fresh"): the
# people-bound demo data goes, the generic categories and catalogue come back, logins and
# screens stay, and the home-control, photo and weather demo data stays until their milestones.
class FreshStartTest < ActiveSupport::TestCase
  test "fresh start keeps logins and screens, clears people and lists, reseeds the catalogue" do
    h = households(:primary)
    Screen.create!(household: h, name: "Kitchen")
    h.fresh_start!

    assert_equal 0, h.people.count
    assert_equal 0, h.events.count
    assert_equal 0, h.routines.count
    assert_equal 0, h.chores.count
    assert_equal 0, h.stores.count
    assert_equal 0, h.grocery_items.count
    assert_equal 0, StarEntry.joins(:person).where(people: { household_id: h.id }).count
    assert_equal 2, h.users.count
    assert_equal 1, h.screens.count
    assert_equal 0, h.devices.count, "the demo home goes too (owner, 2026-10-19)"
    assert_equal 0, h.photos.count, "and the demo photos"

    assert_equal [ "Produce", "Bakery", "Meat & Fish", "Dairy & Eggs", "Pantry", "Frozen", "Snacks", "Household" ], h.categories.reload.map(&:name)
    assert_operator h.catalog_items.count, :>=, 60
    assert_equal "Dairy & Eggs", h.catalog_items.find_by!(name: "Eggs").category.name
    assert_includes h.usuals.map(&:name), "Milk 2%"
  end

  test "the seeds use the same catalogue" do
    h = households(:primary)
    h.catalog_items.destroy_all
    h.categories.destroy_all
    h.seed_catalog!
    assert_equal 8, h.categories.count
    assert_includes h.catalog_items.map(&:name), "Toothpaste"
  end
end
