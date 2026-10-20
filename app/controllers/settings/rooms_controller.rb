class Settings::RoomsController < Settings::BaseController
  before_action :set_room, only: %i[edit update destroy move]

  def index = redirect_to(settings_home_path)
  def new = @room = @household.rooms.new

  def create
    @room = @household.rooms.new(room_params)
    @room.save ? saved(settings_home_path, "#{@room.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @room.update(room_params) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @room.destroy
    saved(settings_home_path, "#{@room.name} removed; its devices are unplaced.")
  end

  def move
    @room.move!(params[:direction], @household.rooms)
    saved(settings_home_path)
  end

  private

  def set_room = @room = @household.rooms.find(params[:id])
  def room_params = params.expect(room: [ :name ])
end
