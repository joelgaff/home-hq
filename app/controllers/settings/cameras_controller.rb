class Settings::CamerasController < Settings::BaseController
  before_action :set_camera, only: %i[edit update destroy move]
  before_action { @entities = HomeAssistant.configured? ? HomeAssistant.entities(%w[camera]) : [] }

  def index = redirect_to(settings_home_path)
  def new = @camera = @household.cameras.new

  def create
    @camera = @household.cameras.new(camera_params)
    @camera.save ? saved(settings_home_path, "#{@camera.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @camera.update(camera_params) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @camera.destroy
    saved(settings_home_path, "#{@camera.name} removed.")
  end

  def move
    @camera.move!(params[:direction], @household.cameras)
    saved(settings_home_path)
  end

  private

  def set_camera = @camera = @household.cameras.find(params[:id])
  def camera_params = params.expect(camera: [ :name, :entity_id ])
end
