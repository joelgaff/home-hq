# "Turn everything off" from the Lights sheet, with Undo (ui-spec §1.6).
class LightsController < ApplicationController
  include ControlChanges

  def destroy
    activation, lights = @household.lights_off!
    render_changes(devices: lights, scenes: true,
      toast: { html: "Turned off #{lights.size} lights", icon: "bulb", undo_path: scene_activation_path(activation) })
  end
end
