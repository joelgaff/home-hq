require "test_helper"

# Shopping rules from docs/ui-spec.md §1.4: per-store aisle order with "Other" last, catalogue
# categorisation, add/bump/revive, check with Undo, the "Got it" drawer and clearing it.
class GroceryItemTest < ActiveSupport::TestCase
  setup { @household = households(:primary) }

  test "open items group by category in the All order with Other last" do
    groups = @household.shopping_groups
    assert_equal [ "Produce", "Bakery", "Dairy & Eggs", "Household", "Other" ], groups.map(&:first)
    assert_equal [ "Bananas", "Avocados" ], groups.first.last.map(&:name)
    assert_equal [ "Birthday candles" ], groups.last.last.map(&:name)
  end

  test "a store filter uses that store's aisle order and only its items" do
    groups = @household.shopping_groups(store: stores(:costco))
    assert_equal [ "Household", "Dairy & Eggs", "Bakery" ], groups.map(&:first)
  end

  test "counts per store for the header" do
    assert_equal 6, @household.grocery_items.open.count
    assert_equal 3, @household.grocery_items.open.where(store: stores(:costco)).count
  end

  test "categorise: exact, then substring, then a word over three letters, else Other" do
    assert_equal "Produce", @household.categorize("bananas").name
    assert_equal "Dairy & Eggs", @household.categorize("Milk").name
    assert_equal "Meat & Fish", @household.categorize("thighs chicken").name
    assert_nil @household.categorize("Glitter")
  end

  test "adding an item already open bumps its quantity" do
    outcome, item = @household.add_grocery("bananas")
    assert_equal :bumped, outcome
    assert_equal 2, item.reload.quantity
  end

  test "adding an item that was checked off revives it at one" do
    outcome, item = @household.add_grocery("Lemons")
    assert_equal :revived, outcome
    assert_nil item.reload.checked_at
    assert_equal 1, item.quantity
  end

  test "adding from a store's tab moves an item already on the list, or checked off, to that store" do
    _, bumped = @household.add_grocery("bananas", store: stores(:costco))
    assert_equal stores(:costco), bumped.reload.store
    _, revived = @household.add_grocery("Lemons", store: stores(:costco))
    assert_equal stores(:costco), revived.reload.store
  end

  test "adding from All leaves the item's store alone" do
    _, item = @household.add_grocery("bananas")
    assert_equal stores(:grocer), item.reload.store
  end

  test "adding a new item uses the catalogue name and category and the chosen store" do
    outcome, item = @household.add_grocery("oat milk", store: stores(:costco))
    assert_equal :added, outcome
    assert_equal "Oat milk", item.name
    assert_equal "Dairy & Eggs", item.category.name
    assert_equal "Costco", item.store.name
  end

  test "an unknown item is capitalised, filed under Other, at the first store" do
    _, item = @household.add_grocery("glitter glue")
    assert_equal "Glitter glue", item.name
    assert_nil item.category
    assert_equal "FreshCo", item.store.name
  end

  test "suggestions: prefix matches first, then substring, five at most" do
    assert_equal [ "Bananas", "Baby spinach", "Bagels" ], @household.suggest("ba").map(&:name)
    assert_equal [ "Peanut butter", "Butter" ].sort, @household.suggest("utter").map(&:name).sort
    assert_equal 5, @household.suggest("a").size
  end

  test "usuals are the catalogue's usual items, in order" do
    assert_equal [ "Apples", "Bananas", "Baby spinach", "Bread", "Butter", "Eggs", "Milk 2%", "Paper towels", "Chicken thighs" ], @household.usuals.map(&:name)
  end

  test "checking and unchecking" do
    grocery_items(:bananas).check!
    assert grocery_items(:bananas).reload.checked?
    grocery_items(:bananas).uncheck!
    assert_not grocery_items(:bananas).reload.checked?
  end

  test "quantity never drops below one" do
    grocery_items(:bananas).adjust_quantity!(-1)
    assert_equal 1, grocery_items(:bananas).reload.quantity
    grocery_items(:avocados).adjust_quantity!(2)
    assert_equal 5, grocery_items(:avocados).reload.quantity
  end

  test "clearing the checked items hides them, and can be undone" do
    cleared = @household.clear_checked!
    assert_equal 2, cleared.size
    assert_empty @household.grocery_items.checked
    @household.restore_cleared!(cleared.map(&:id))
    assert_equal 2, @household.grocery_items.checked.count
  end

  test "a cleared item does not come back as a revival" do
    @household.clear_checked!
    outcome, item = @household.add_grocery("Lemons")
    assert_equal :added, outcome
    assert_not_equal grocery_items(:lemons).id, item.id
  end
end
