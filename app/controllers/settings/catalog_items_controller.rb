class Settings::CatalogItemsController < Settings::BaseController
  before_action :set_item, only: %i[edit update destroy move]

  def index
    @items = @household.catalog_items.includes(:category)
  end

  def new
    @item = @household.catalog_items.new
  end

  def create
    @item = @household.catalog_items.new(item_params)
    @item.save ? saved(settings_catalog_items_path, "#{@item.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @item.update(item_params) ? saved(settings_catalog_items_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @item.destroy
    saved(settings_catalog_items_path, "#{@item.name} removed.")
  end

  def move
    @item.move!(params[:direction], @household.catalog_items)
    saved(settings_catalog_items_path)
  end

  private

  def set_item
    @item = @household.catalog_items.find(params[:id])
  end

  def item_params
    attrs = params.expect(catalog_item: %i[name category_id usual])
    attrs[:category_id] = @household.categories.find_by(id: attrs[:category_id])&.id if attrs.key?(:category_id)
    attrs
  end
end
