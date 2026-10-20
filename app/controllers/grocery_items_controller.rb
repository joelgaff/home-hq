# Writes on the shopping list (ui-spec §1.4). Each answer is a Turbo Stream re-rendering the
# list, the side panel and the Today card, plus a toast where the spec has one.
class GroceryItemsController < ApplicationController
  include ShoppingContext

  def create
    outcome, item = @household.add_grocery(params[:name].to_s, store: @store)
    @flash_id = item.id
    @toast = case outcome
    when :bumped then { html: "Already on the list · now <b>×#{item.quantity}</b> #{h(item.name)}", icon: "cart", ms: 3000 }
    when :revived then { html: "Added back <b>#{h(item.name)}</b>", icon: "cart", ms: 3000 }
    else { html: "Added <b>#{h(item.name)}</b> to #{h(item.category_name)}", icon: "cart", ms: 3000 }
    end
    render :changed
  end

  # The edit sheet (plan: second review 2026-10-16): name, note, store, category, quantity.
  def edit
    @item = @household.grocery_items.find(params[:id])
    render partial: "grocery_items/edit", layout: false
  end

  # A quantity nudge from the row (delta, sent as JSON, which parameter wrapping would otherwise
  # turn into an empty grocery_item), or the sheet's fields.
  def update
    @item = @household.grocery_items.find(params[:id])
    if params.key?(:delta)
      @item.adjust_quantity!(params[:delta].to_i)
      render :row
    else
      if @item.update(item_params)
        changes = @item.saved_changes.except("updated_at")
        AuditEntry.record("grocery.updated", household: @household, subject: @item, subject_name: @item.name, details: { "changes" => changes }) if changes.any?
        @toast = { html: "Saved <b>#{h(@item.name)}</b>", icon: "cart", ms: 2000 }
      else
        @toast = { html: "An item needs a name", tone: "error", icon: "bolt", ms: 2500 }
      end
      render :changed
    end
  end

  def destroy
    @item = @household.grocery_items.find(params[:id])
    @item.destroy
    AuditEntry.record("grocery.removed", household: @household, subject_name: @item.name)
    @toast = { html: "Removed <b>#{h(@item.name)}</b>", icon: "x", ms: 2500 }
    render :changed
  end

  def check
    item = @household.grocery_items.find(params[:id])
    item.check!
    @toast = { html: "<b>#{h(item.name)}</b> checked off", icon: "check", undo_path: check_grocery_item_path(item), undo_params: shopping_context }
    render :changed
  end

  def uncheck
    item = @household.grocery_items.find(params[:id])
    item.uncheck!
    @toast = { html: "Added back <b>#{h(item.name)}</b>", icon: "cart", ms: 2500 } if @drawer
    render :changed
  end

  private

  def item_params
    permitted = params.expect(grocery_item: %i[name note store_id category_id quantity])
    # Every item has a store: a blank or foreign one keeps the item's own.
    permitted[:store_id] = @household.stores.find_by(id: permitted[:store_id])&.id || @item.store_id if permitted.key?(:store_id)
    permitted[:category_id] = @household.categories.find_by(id: permitted[:category_id])&.id if permitted.key?(:category_id)
    permitted[:quantity] = [ permitted[:quantity].to_i, 1 ].max if permitted.key?(:quantity)
    permitted[:note] = permitted[:note].to_s.strip.presence if permitted.key?(:note)
    permitted
  end

  def h(text)
    ERB::Util.html_escape(text)
  end
end
