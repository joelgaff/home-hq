# Scenes (ui-spec §1.6): activate with a snapshot, Undo reverts it.
class SceneActivationsController < ApplicationController
  include ControlChanges

  def create
    scene = @household.scenes.find(params[:scene_id])
    activation = scene.activate!
    render_changes(devices: activation.changed_devices.to_a, scenes: true,
      toast: { html: "<b>#{ERB::Util.html_escape(scene.name)}</b> scene on", icon: scene.icon, undo_path: scene_activation_path(activation) })
  end

  def destroy
    activation = @household.scene_activations.find(params[:id])
    activation.revert!
    render_changes(devices: activation.changed_devices.to_a, scenes: true)
  end
end
