# Climate (ui-spec §1.6): setpoint steps and the mode.
class ThermostatsController < ApplicationController
  def update
    @household = Current.household
    thermostat = @household.thermostat
    thermostat.adjust!(params[:delta].to_f) if params[:delta].present?
    thermostat.set_mode!(params[:mode]) if params[:mode].present?
    render :changed
  end
end
