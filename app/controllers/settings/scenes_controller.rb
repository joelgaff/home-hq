class Settings::ScenesController < Settings::BaseController
  before_action :set_scene, only: %i[edit update destroy move]
  before_action { @devices = @household.devices.includes(:deviceable, :room).reject(&:door_lock?) }

  def index = redirect_to(settings_home_path)
  def new = @scene = @household.scenes.new

  def create
    @scene = @household.scenes.new(scene_params)
    @scene.save ? saved(settings_home_path, "#{@scene.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @scene.update(scene_params) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @scene.destroy
    saved(settings_home_path, "#{@scene.name} removed.")
  end

  def move
    @scene.move!(params[:direction], @household.scenes)
    saved(settings_home_path)
  end

  private

  def set_scene = @scene = @household.scenes.find(params[:id])

  def scene_params
    permitted = params.expect(scene: [ :name, :icon, :locks_all, :entity_id, levels: {} ])
    permitted[:levels] = permitted[:levels].to_h.slice(*@devices.map { |d| d.id.to_s }) if permitted.key?(:levels)
    permitted
  end
end
