# The Chores view (ui-spec §1.3): the current routine, or another one picked from the toggle.
class ChoresController < ApplicationController
  def show
    @household = Current.household
    routine = @household.routines.find_by(id: params[:routine]) || @household.current_routine
    render partial: "chores/chores", locals: { routine: routine }, layout: false
  end
end
