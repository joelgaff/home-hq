require "test_helper"

# The Shopping view (docs/ui-spec.md §1.4).
class ShoppingControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  def row(item) = "#grocery_item_#{item.id}"

  test "the dashboard page carries the shopping frames and the add box" do
    get root_path
    assert_select "#view-shopping .shop turbo-frame#shopping .s-list", 1
    assert_select "#view-shopping .s-side .s-add input.s-input[placeholder='Add an item…']", 1
    assert_select "#view-shopping turbo-frame#shopping-side .s-usuals", 1
  end

  test "header: title, count, store filter with counts" do
    get shopping_path
    assert_select "#shopping .s-head h1", "Groceries"
    assert_select "#shopping .s-count", /6\s*to get/
    assert_select "#shopping .s-stores a", 3
    assert_select "#shopping .s-stores a.is-on", /All\s*6/
    assert_select "#shopping .s-stores a[href=?]", shopping_path(store: stores(:costco).id), /Costco\s*3/
  end

  test "the list groups by category in aisle order with counts, notes, store badges and quantities" do
    get shopping_path
    assert_select "#shopping .s-cat" do |cats|
      assert_equal [ "Produce", "Bakery", "Dairy & Eggs", "Household", "Other" ], cats.map { |c| c["data-cat"] }
    end
    assert_select "#shopping .s-cat[data-cat=Produce] [data-cat-count]", "2"
    assert_select row(grocery_items(:bananas)) do
      assert_select ".s-name b", "Bananas"
      assert_select ".s-name small", "Bunch, not too ripe"
      assert_select ".s-qty .num", "1"
      assert_select ".s-store", "FreshCo", "the first store's items carry their badge too, so a store choice shows"
    end
    assert_select "#{row(grocery_items(:bagels))} .s-store", "Costco"
    assert_select "#shopping .s-drawer:not(.is-open) .s-drawer-h", /Got it\s*\(2\)\s*Show/
    assert_select "#shopping .s-drawer-list", 0
  end

  test "a store filter shows its items in its aisle order and no badges" do
    get shopping_path(store: stores(:costco).id)
    assert_select "#shopping .s-cat" do |cats|
      assert_equal [ "Household", "Dairy & Eggs", "Bakery" ], cats.map { |c| c["data-cat"] }
    end
    assert_select "#shopping .s-store", 0
    assert_select "#shopping .s-count", /3\s*to get/
    assert_select "#shopping[data-store='#{stores(:costco).id}']"
  end

  test "the open drawer lists checked items with Add back and a Clear button" do
    get shopping_path(drawer: 1)
    assert_select "#shopping .s-drawer.is-open .s-drawer-h", /Hide/
    assert_select "#shopping .s-drawer-list .s-got", 2
    assert_select "#shopping .s-drawer-list .s-got", /Lemons\s*Add back/
    assert_select "#shopping .s-clear", "Clear 2 checked items"
  end

  test "an empty list says so" do
    households(:primary).grocery_items.open.update_all(checked_at: Time.current)
    get shopping_path
    assert_select "#shopping .s-empty", /All stocked up/
  end

  test "the side panel: usual tiles marked when on the list, and the catalogue for suggestions" do
    get root_path
    assert_select "#shopping-side .s-tile", 9
    assert_select "#shopping-side .s-tile.is-on[data-add=Bananas] span", /On list/
    assert_select "#shopping-side .s-tile:not(.is-on)[data-add=Apples] span", "Produce"
    assert_select "#view-shopping .s-side[data-suggest-catalog-value*='Baby spinach']"
    assert_select "#shopping-side[data-on-list*='\"Bananas\":1']"
  end

  test "adding a new item inserts it, flashes it, updates the side panel and toasts" do
    post grocery_items_path, params: { name: "oat milk" }, as: :turbo_stream
    item = GroceryItem.find_by(name: "Oat milk")
    assert_select "turbo-stream[action=replace][target=shopping] #{row(item)}.is-flash", 1
    assert_select "turbo-stream[action=replace][target=shopping-side]", 1
    assert_select "turbo-stream[action=replace][target=today-shopping]", 1
    assert_select "turbo-stream[target=toasts] .toast-msg", /Added\s*Oat milk\s*to Dairy & Eggs/
  end

  test "adding an open item bumps it; a checked one comes back" do
    post grocery_items_path, params: { name: "Bananas" }, as: :turbo_stream
    assert_equal 2, grocery_items(:bananas).reload.quantity
    assert_select "turbo-stream[target=toasts] .toast-msg", /Already on the list · now\s*×2\s*Bananas/
    post grocery_items_path, params: { name: "lemons" }, as: :turbo_stream
    assert_not grocery_items(:lemons).reload.checked?
    assert_select "turbo-stream[target=toasts] .toast-msg", /Added back\s*Lemons/
  end

  test "adding into a store filter keeps the filter" do
    post grocery_items_path, params: { name: "Rice", store: stores(:costco).id }, as: :turbo_stream
    assert_equal "Costco", GroceryItem.find_by(name: "Rice").store.name
    assert_select "turbo-stream[target=shopping] #shopping[data-store='#{stores(:costco).id}']"
  end

  test "checking an item removes it from the list and offers Undo; Undo brings it back" do
    patch check_grocery_item_path(grocery_items(:bananas)), as: :turbo_stream
    assert grocery_items(:bananas).reload.checked?
    assert_select "turbo-stream[target=shopping] #{row(grocery_items(:bananas))}", 0
    assert_select "turbo-stream[target=toasts] .toast-msg", /Bananas\s*checked off/
    assert_select "turbo-stream[target=toasts] form[action=?] input[name=_method][value=delete]", check_grocery_item_path(grocery_items(:bananas))

    delete check_grocery_item_path(grocery_items(:bananas)), as: :turbo_stream
    assert_not grocery_items(:bananas).reload.checked?
    assert_select "turbo-stream[target=shopping] #{row(grocery_items(:bananas))}", 1
  end

  test "Add back from the drawer revives the item with a toast" do
    delete check_grocery_item_path(grocery_items(:lemons)), params: { drawer: 1 }, as: :turbo_stream
    assert_not grocery_items(:lemons).reload.checked?
    assert_select "turbo-stream[target=toasts] .toast-msg", /Added back\s*Lemons/
    assert_select "turbo-stream[target=shopping] .s-drawer.is-open", 1
  end

  test "quantity changes replace just the row and the side panel, never below one" do
    patch grocery_item_path(grocery_items(:bananas)), params: { delta: 1 }, as: :turbo_stream
    assert_equal 2, grocery_items(:bananas).reload.quantity
    assert_select "turbo-stream[action=replace][target=#{row(grocery_items(:bananas)).delete('#')}] .s-qty .num", "2"
    assert_select "turbo-stream[target=shopping-side] .s-tile[data-add=Bananas] span", /×2/
    assert_select "turbo-stream[target=shopping]", 0
    patch grocery_item_path(grocery_items(:avocados)), params: { delta: -5 }, as: :turbo_stream
    assert_equal 1, grocery_items(:avocados).reload.quantity
  end

  test "clearing the checked items can be undone" do
    post cleared_groceries_path, as: :turbo_stream
    assert_empty households(:primary).grocery_items.checked
    assert_select "turbo-stream[target=shopping] .s-drawer", 0
    assert_select "turbo-stream[target=toasts] .toast-msg", "Cleared 2 items"
    ids = [ grocery_items(:lemons).id, grocery_items(:butter).id ]
    assert_select "turbo-stream[target=toasts] form[action=?]", cleared_groceries_path(ids: ids.sort.join(","))

    delete cleared_groceries_path(ids: ids.join(",")), as: :turbo_stream
    assert_equal 2, households(:primary).grocery_items.checked.count
  end
end
