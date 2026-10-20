class Settings::TodosController < Settings::BaseController
  before_action :set_todo, only: %i[edit update destroy move]

  def index
    @todos = @household.todos.includes(:person).order(Arel.sql("done_at IS NOT NULL, due_on IS NULL, due_on, id"))
  end

  def new = @todo = @household.todos.new

  def create
    @todo = @household.todos.new(todo_params.merge(created_by: current_user&.person&.name || current_user&.email))
    @todo.save ? saved(settings_todos_path, "#{@todo.title} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @todo.update(todo_params) ? saved(settings_todos_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @todo.destroy
    saved(settings_todos_path, "#{@todo.title} removed.")
  end

  def move = saved(settings_todos_path)

  private

  def set_todo = @todo = @household.todos.find(params[:id])

  def todo_params
    permitted = params.expect(todo: %i[title person_id due_on due_at stars])
    permitted[:person_id] = @household.people.find_by(id: permitted[:person_id])&.id if permitted.key?(:person_id)
    permitted[:stars] = permitted[:stars].to_i if permitted.key?(:stars)
    permitted
  end
end
