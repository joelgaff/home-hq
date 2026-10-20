# The demo drawer's server-side presets (ui-spec §1.9), kept in this browser's session: a time
# of day the dashboard pretends it is, and the calendar data mode. The page reloads to apply.
class DemoController < ApplicationController
  CALENDAR_MODES = %w[normal empty busy].freeze

  before_action { head :not_found unless Current.household.demo? }

  def update
    if params[:time].present?
      if params[:time] == "real"
        session.delete(:clock_offset)
        session.delete(:demo_time)
      elsif (m = params[:time].match(/\A(\d{1,2}):(\d{2})\z/))
        target = Time.current.change(hour: m[1].to_i, min: m[2].to_i)
        session[:clock_offset] = (target - Time.current).to_i
        session[:demo_time] = params[:time]
      end
    end
    if CALENDAR_MODES.include?(params[:calendar])
      params[:calendar] == "normal" ? session.delete(:calendar_mode) : session[:calendar_mode] = params[:calendar]
    end
    redirect_to root_path
  end
end
