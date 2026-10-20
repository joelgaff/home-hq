# To-dos from the screens (plan: People view): add, tick off, undo, remove. Answers with the
# Today lanes (and the phone's agenda), a toast, and a nudge to refetch the chores and people
# pieces, which depend on the page's context.
class TodosController < ApplicationController
  before_action { @household = Current.household }
  before_action :set_todo, only: %i[complete undo destroy]

  def create
    @todo = @household.todos.new(todo_params.merge(created_by: current_user&.person&.name || current_user&.email || current_screen&.name))
    @todo.person = @household.people.find_by(id: todo_params[:person_id])
    if @todo.save
      @toast = { html: "To-do added for #{@todo.person&.name || 'anyone'}", icon: "check", ms: 2000 }
    else
      @toast = { html: "A to-do needs a title", tone: "error", icon: "bolt", ms: 2500 }
    end
    render :changed
  end

  def complete
    by = @household.people.find_by(id: params[:person_id]) || current_user&.person
    @todo.complete!(by: by)
    earned = @todo.star_entries.first
    @toast = { html: "<b>#{ERB::Util.html_escape(@todo.title)}</b> done#{earned ? " · +#{earned.amount}★ #{ERB::Util.html_escape(earned.person.name)}" : ''}", icon: "check", ms: 2500, undo_path: undo_todo_path(@todo), undo_method: :patch }
    render :changed
  end

  def undo
    @todo.undo!
    @toast = nil
    render :changed
  end

  def destroy
    @todo.destroy
    @toast = { html: "To-do removed", icon: "x", ms: 2000 }
    render :changed
  end

  private

  def set_todo
    @todo = @household.todos.find(params[:id])
  end

  def todo_params
    permitted = params.expect(todo: %i[title person_id due_on due_at stars])
    permitted[:stars] = permitted[:stars].to_i if permitted.key?(:stars)
    permitted
  end
end
