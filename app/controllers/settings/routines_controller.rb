class Settings::RoutinesController < Settings::BaseController
  before_action :set_routine, only: %i[edit update destroy move]

  def index
    @routines = @household.routines
  end

  def new
    @routine = @household.routines.new(from_hour: 17, to_hour: 22)
  end

  def create
    @routine = @household.routines.new(routine_params)
    @routine.save ? saved(settings_routines_path, "#{@routine.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @routine.update(routine_params) ? saved(settings_routines_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @routine.destroy
    saved(settings_routines_path, "#{@routine.name} removed, with its chores.")
  end

  def move
    @routine.move!(params[:direction], @household.routines)
    saved(settings_routines_path)
  end

  private

  def set_routine
    @routine = @household.routines.find(params[:id])
  end

  def routine_params
    attrs = params.expect(routine: [ :name, :range_label, :from_hour, :to_hour, weekdays: [] ])
    attrs[:weekday_names] = attrs.delete(:weekdays) if attrs.key?(:weekdays)
    attrs
  end
end
