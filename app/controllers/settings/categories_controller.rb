class Settings::CategoriesController < Settings::BaseController
  before_action :set_category, only: %i[edit update destroy move]

  def index
    @categories = @household.categories
  end

  def new
    @category = @household.categories.new
  end

  def create
    @category = @household.categories.new(category_params)
    @category.save ? saved(settings_categories_path, "#{@category.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @category.update(category_params) ? saved(settings_categories_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @category.destroy
    saved(settings_categories_path, "#{@category.name} removed; its items are under Other.")
  end

  def move
    @category.move!(params[:direction], @household.categories)
    saved(settings_categories_path)
  end

  private

  def set_category
    @category = @household.categories.find(params[:id])
  end

  def category_params
    params.expect(category: [ :name ])
  end
end
