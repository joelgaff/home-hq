require "application_system_test_case"

# Shopping in the browser: usuals and typed suggestions add items, checking is pending for a
# moment with a cancellable toast, quantities patch in place.
class ShoppingTest < ApplicationSystemTestCase
  setup do
    show_on_screen
    find(".rail-item[data-go=shopping]").click
    assert_selector "#view-shopping.is-active"
  end

  test "a usual tile adds the item, flashes it and marks the tile" do
    find("#shopping-side .s-tile[data-add=Apples]").click
    assert_selector "#shopping .s-cat[data-cat=Produce] .s-row", text: /apples/i
    assert_selector "#shopping-side .s-tile.is-on[data-add=Apples]"
    assert_selector "#toasts .toast-msg", text: /added\s*apples\s*to produce/i
    assert_selector "#shopping .s-count", text: /7\s*to get/i
  end

  test "typing suggests catalogue items and Enter adds the typed text" do
    fill_in placeholder: "Add an item…", with: "oat"
    assert_selector ".s-side .s-ac-row", text: /oat milk/i
    assert_no_selector "#shopping-side .s-usuals"
    fill_in placeholder: "Add an item…", with: "glitter glue"
    assert_selector ".s-side .s-ac-row--new .label", text: /other/i
    find(".s-input").send_keys(:enter)
    assert_selector "#shopping .s-cat[data-cat=Other] .s-row", text: /glitter glue/i
    assert_equal "", find(".s-input").value
    assert_selector "#shopping-side .s-usuals"
  end

  test "checking strikes the row and toasts at once; a second tap cancels; otherwise it commits" do
    row = "#grocery_item_#{grocery_items(:avocados).id}"
    find("#{row} .s-hit").click
    assert_selector "#{row}.is-checking"
    assert_selector "#toasts .toast-msg", text: /avocados\s*checked off/i
    find("#toasts [data-toast-undo]").click
    assert_no_selector "#{row}.is-checking"
    assert_no_selector "#toasts .toast:not(.toast--tip)"  # the demo tip does not count

    find("#{row} .s-hit").click
    assert_no_selector row, wait: 5
    assert_selector "#shopping .s-drawer-h", text: /got it\s*\(3\)/i
    find("#toasts .toast-undo").click
    assert_selector row, wait: 5
  end

  test "quantity buttons update the row" do
    row = "#grocery_item_#{grocery_items(:avocados).id}"
    find("#{row} [data-delta='1']").click
    assert_selector "#{row} .s-qty .num", text: "4"
    # The row updates before the server answers (optimistic); give the write a moment.
    20.times { break if grocery_items(:avocados).reload.quantity == 4; sleep 0.25 }
    assert_equal 4, grocery_items(:avocados).reload.quantity
  end

  test "three stores with long names still fit: the side panel stays on the screen" do
    households(:primary).stores.create!(name: "99 Ranch Market", position: 9)
    households(:primary).stores.first.update!(name: "Trader Joe's Hollywood")
    visit root_path
    find(".rail-item[data-go=shopping]").click
    assert_selector "#shopping .s-stores a", count: 4
    side = evaluate_script("document.querySelector('.s-side').getBoundingClientRect().right")
    assert_operator side, :<=, evaluate_script("innerWidth"), "the side panel runs off the right edge"
    assert_equal evaluate_script("innerWidth"), evaluate_script("document.documentElement.scrollWidth")
  end

  test "the trash button on a row removes the item, on the same store tab" do
    item = grocery_items(:bananas)
    find("#shopping .s-stores a[data-store='#{item.store_id}']").click
    assert_selector "#shopping .s-stores a.is-on[data-store='#{item.store_id}']"
    within("#grocery_item_#{item.id}") { find(".s-trash").click }
    assert_no_selector "#grocery_item_#{item.id}"
    assert_selector "#toasts .toast-msg", text: /removed\s*bananas/i
    assert_selector "#shopping .s-stores a.is-on[data-store='#{item.store_id}']"
    assert_nil GroceryItem.find_by(id: item.id)
  end

  test "the edit sheet's fields are styled and stay inside the sheet" do
    item = grocery_items(:bananas)
    within("#grocery_item_#{item.id}") { find(".s-edit:not(.s-trash)").click }
    assert_selector "#sheet form.gi-form input[name='grocery_item[quantity]']"
    sheet = evaluate_script("document.querySelector('.sheet').getBoundingClientRect().right")
    %w[name note quantity].each do |field|
      right = evaluate_script("document.querySelector(\"[name='grocery_item[#{field}]']\").getBoundingClientRect().right")
      assert_operator right, :<=, sheet, "#{field} runs out of the sheet"
    end
    assert_equal "56px", evaluate_script("getComputedStyle(document.querySelector(\"[name='grocery_item[store_id]']\")).height")
  end
end
