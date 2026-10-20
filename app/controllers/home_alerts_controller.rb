# The frame (or a phone) acknowledging an alert (plan: milestone 6): dismissed, "Leave open", seen.
class HomeAlertsController < ApplicationController
  def acknowledge
    alert = Current.household.home_alerts.find(params[:id])
    alert.acknowledge!(by: current_user&.person&.name || current_user&.email || current_screen&.name) unless alert.acknowledged?
    head :no_content
  end
end
