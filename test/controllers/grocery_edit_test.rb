require "test_helper"

# Editing or removing one grocery item (plan: second review 2026-10-16): a pencil on the row opens
# a sheet with the name, note, store, category and quantity; Save or Remove re-renders the list.
class GroceryEditTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    @item = grocery_items(:bananas)
  end

  test "the row offers an edit sheet with the item's fields" do
    get shopping_path
    assert_select "#grocery_item_#{@item.id} [data-sheet-url=?]", edit_grocery_item_path(@item)
    get edit_grocery_item_path(@item)
    assert_response :success
    assert_select "turbo-frame#sheet form[action=?]", grocery_item_path(@item) do
      assert_select "input[name='grocery_item[name]'][value=?]", @item.name
      assert_select "input[name='grocery_item[note]']", 1
      assert_select "select[name='grocery_item[store_id]']", 1
      assert_select "select[name='grocery_item[category_id]']", 1
      assert_select "input[name='grocery_item[quantity]']", 1
    end
    assert_select "turbo-frame#sheet form[action=?][method=post] input[name=_method][value=delete]", grocery_item_path(@item)
  end

  test "saving changes the item and re-renders the list; removing takes it off" do
    other_store = households(:primary).stores.last
    category = households(:primary).categories.first
    patch grocery_item_path(@item), params: { grocery_item: { name: "Plantains", note: "ripe", store_id: other_store.id, category_id: category.id, quantity: 3 } }, as: :turbo_stream
    assert_response :success
    @item.reload
    assert_equal [ "Plantains", "ripe", other_store, category, 3 ], [ @item.name, @item.note, @item.store, @item.category, @item.quantity ]
    assert_select "turbo-stream[action=replace][target=shopping]", 1
    assert_select "turbo-stream[target=toasts]", text: /Plantains/

    patch grocery_item_path(@item), params: { grocery_item: { name: "" } }, as: :turbo_stream
    assert_equal "Plantains", @item.reload.name, "a blank name is refused"

    delete grocery_item_path(@item), as: :turbo_stream
    assert_response :success
    assert_nil GroceryItem.find_by(id: @item.id)
    assert_select "turbo-stream[action=replace][target=shopping]", 1
    assert_select "turbo-stream[target=toasts]", text: /removed/i
  end

  test "a quantity nudge still works through the same update, sent as JSON like the page does" do
    patch grocery_item_path(@item), params: { delta: 1 }, as: :json, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal 2, @item.reload.quantity
  end

  test "the sheet's save and remove go in the audit log; a quantity nudge does not" do
    patch grocery_item_path(@item), params: { delta: 1 }, as: :json, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_not AuditEntry.exists?(action: "grocery.updated")
    patch grocery_item_path(@item), params: { grocery_item: { name: "Plantains" } }, as: :turbo_stream
    entry = AuditEntry.find_by!(action: "grocery.updated")
    assert_equal "changed Plantains on the shopping list (name)", entry.sentence.sub(/\A\S+ /, "")
    delete grocery_item_path(@item), as: :turbo_stream
    assert_equal "removed Plantains from the shopping list", AuditEntry.find_by!(action: "grocery.removed").sentence.sub(/\A\S+ /, "")
  end

  test "the sheet keeps the list's store tab: Save and Remove carry it and the list comes back on it" do
    store = @item.store || households(:primary).stores.first
    @item.update!(store: store)
    get edit_grocery_item_path(@item, store: store.id)
    assert_select "turbo-frame#sheet form[action=?]", grocery_item_path(@item, store: store.id)
    assert_select "turbo-frame#sheet form[action=?] input[name=_method][value=delete]", grocery_item_path(@item, store: store.id)

    patch grocery_item_path(@item, store: store.id), params: { grocery_item: { note: "ripe" } }, as: :turbo_stream
    assert_select "turbo-stream[target=shopping] .s-stores a.is-on[data-store=?]", store.id.to_s
  end

  test "every item has a store: the sheet offers no blank choice, and a blank keeps the store" do
    store = @item.store
    get edit_grocery_item_path(@item)
    assert_select "select[name='grocery_item[store_id]'] option[value='']", 0
    patch grocery_item_path(@item), params: { grocery_item: { store_id: "" } }, as: :turbo_stream
    assert_response :success
    assert_equal store, @item.reload.store
  end
end
