# One press of a scene button (or "Turn everything off"), with the device states it replaced:
# `revert!` is the Undo.
class SceneActivation < ApplicationRecord
  belongs_to :household
  belongs_to :scene, optional: true

  def changed_device_ids
    snapshot.keys.map(&:to_i)
  end

  def changed_devices
    household.devices.where(id: changed_device_ids).includes(:deviceable, :room)
  end

  def revert!
    transaction do
      changed_devices.each { |device| device.restore(snapshot[device.id.to_s]) }
      household.update!(active_scene: nil) if household.active_scene == scene
    end
  end
end
