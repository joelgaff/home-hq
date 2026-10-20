# Auto-relock (plan: milestone 6): a door unlocked from the doorbell takeover locks itself again
# two minutes later, unless it is locked already.
class RelockJob < ApplicationJob
  queue_as :default

  def perform(device_id)
    device = Device.includes(:deviceable).find_by(id: device_id)
    return unless device&.door_lock? && !device.locked?
    Current.household = device.household
    Time.use_zone(device.household.time_zone) do
      device.apply({ locked: true }, audit: false) && AuditEntry.record("device.relocked", household: device.household, subject: device)
    end
  ensure
    Current.household = nil
  end
end
