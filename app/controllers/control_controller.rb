# The Home control view (ui-spec §1.6).
class ControlController < ApplicationController
  def show
    render partial: "control/view", layout: false
  end
end
