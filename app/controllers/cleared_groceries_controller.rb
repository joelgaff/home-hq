# "Clear N checked items" and its Undo (ui-spec §1.4).
class ClearedGroceriesController < ApplicationController
  include ShoppingContext

  def create
    items = @household.clear_checked!
    @drawer = false
    @toast = { html: "Cleared #{items.size} items", icon: "check",
               undo_path: cleared_groceries_path(ids: items.map(&:id).sort.join(",")), undo_params: shopping_context }
    render "grocery_items/changed"
  end

  def destroy
    @household.restore_cleared!(params[:ids].to_s.split(",").map(&:to_i))
    @toast = nil
    render "grocery_items/changed"
  end
end
