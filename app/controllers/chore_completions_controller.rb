# Completing (and un-completing) chores (ui-spec §1.3). Every answer is a Turbo Stream that
# re-renders the Chores view and the Today card; completing adds a toast with Undo.
class ChoreCompletionsController < ApplicationController
  before_action { @household = Current.household }
  before_action :set_routine

  # "Who did it?" for an Anyone chore.
  def new
    @chore = @household.chores.find(params[:chore_id])
    render partial: "chore_completions/new", layout: false
  end

  def create
    @chore = @household.chores.find(params[:chore_id])
    by = @household.people.find_by(id: params[:person_id])
    @completion = @chore.complete!(by: by)
    @toast = completion_toast
    render :changed
  end

  def destroy
    completion = ChoreCompletion.joins(:chore).where(chores: { household_id: @household.id }).find(params[:id])
    completion.undo!
    @toast = nil
    render :changed
  end

  private

  def set_routine
    @routine = @household.routines.find_by(id: params[:routine]) || @household.current_routine
  end

  def completion_toast
    routine = @chore.routine
    if routine.chores.includes(:completions_today).all?(&:done?)
      { html: "<b>#{ERB::Util.html_escape(routine.name)} routine complete!</b> Everyone crushed it.", icon: "star", ms: 5000 }
    else
      earner = @chore.star_earner(@completion.person)
      stars = earner && @chore.stars.positive? ? " · +#{@chore.stars}★ #{ERB::Util.html_escape(earner.name)}" : ""
      { html: "<b>#{ERB::Util.html_escape(@chore.title)}</b> done#{stars}", icon: "check", undo_path: chore_completion_path(@completion) }
    end
  end
end
