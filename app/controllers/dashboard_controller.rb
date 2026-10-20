# The one page the frame and phones show: the stage with its rail and every view already in the
# DOM. Tabs switch client-side; data arrives as Turbo Frames and Streams (docs/plan.md).
class DashboardController < ApplicationController
  layout "dashboard"

  def show
    @household = Current.household
    @screen = current_screen || Screen.new
  end
end
