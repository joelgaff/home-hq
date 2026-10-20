# The Today view (ui-spec §1.1). The dashboard page renders it whole; the frame asks for one
# piece at a time afterwards (`?part=hero`), each piece being a Turbo Frame.
class TodayController < ApplicationController
  # The part name maps to its partial through this table, never straight from the parameter.
  PARTS = %w[clock weather presence hero lanes agenda chores shopping status photo ambient_info night_info]
    .to_h { |part| [ part, "today/#{part}" ] }.freeze

  def show
    @household = Current.household
    partial = params[:part].present? ? PARTS[params[:part]] : "today/home"
    head :not_found and return unless partial
    render partial: partial, layout: false
  end
end
