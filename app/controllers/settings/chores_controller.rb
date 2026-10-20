class Settings::ChoresController < Settings::BaseController
  # A chore lives in a routine (the one hard step in the setup order).
  before_action :require_a_routine, only: %i[new create]
  before_action :set_chore, only: %i[edit update destroy move]

  def index
    @routines = @household.routines.includes(chores: :person)
  end

  def new
    @chore = @household.chores.new(routine: @household.routines.find_by(id: params[:routine_id]) || @household.routines.first, stars: 1, emoji: "✅")
  end

  def create
    @chore = @household.chores.new(chore_params)
    @chore.save ? saved(settings_chores_path, "#{@chore.title} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @chore.update(chore_params) ? saved(settings_chores_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @chore.destroy
    saved(settings_chores_path, "#{@chore.title} removed.")
  end

  def move
    @chore.move!(params[:direction], @chore.lane_siblings)
    saved(settings_chores_path)
  end

  private

  def set_chore
    @chore = @household.chores.find(params[:id])
  end

  def chore_params
    attrs = params.expect(chore: [ :title, :emoji, :stars, :routine_id, :person_id, weekdays: [] ])
    attrs[:weekday_names] = attrs.delete(:weekdays) if attrs.key?(:weekdays)
    attrs[:routine_id] = @household.routines.find(attrs[:routine_id]).id if attrs[:routine_id].present?
    attrs[:person_id] = @household.people.find_by(id: attrs[:person_id])&.id if attrs.key?(:person_id)
    attrs
  end

  def require_a_routine
    redirect_to settings_routines_path, alert: "Add a routine first: chores live in one." unless @household.routines.exists?
  end
end
