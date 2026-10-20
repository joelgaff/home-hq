# A store's aisle order: move a category up or down (plan: Our instance).
class Settings::AislesController < Settings::BaseController
  def move
    store = @household.stores.find(params[:store_id])
    store.move_aisle!(@household.categories.find(params[:id]), params[:direction])
    saved(settings_store_path(store))
  end
end
