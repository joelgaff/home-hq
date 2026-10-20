class Settings::StoresController < Settings::BaseController
  before_action :set_store, only: %i[show edit update destroy move]

  def index
    @stores = @household.stores
  end

  # The store's aisle order (categories, movable).
  def show
    @aisle = @store.aisle_order
  end

  def new
    @store = @household.stores.new
  end

  def create
    @store = @household.stores.new(store_params)
    @store.save ? saved(settings_stores_path, "#{@store.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @store.update(store_params) ? saved(settings_stores_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @store.destroy
    saved(settings_stores_path, "#{@store.name} removed.")
  end

  def move
    @store.move!(params[:direction], @household.stores)
    saved(settings_stores_path)
  end

  private

  def set_store
    @store = @household.stores.find(params[:id])
  end

  def store_params
    params.expect(store: [ :name ])
  end
end
