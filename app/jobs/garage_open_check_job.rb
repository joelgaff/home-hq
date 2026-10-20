# The garage-open banner (plan: milestone 6; ui-spec §1.9): scheduled when the garage opens; if
# it is still open (and has not moved since), the screens get a banner saying for how long and
# who is how far away, unless someone chose "Leave open" since it opened. Checks again later.
class GarageOpenCheckJob < ApplicationJob
  queue_as :default

  AFTER = 15.minutes

  def perform(device_id, opened_at)
    device = Device.includes(:deviceable).find_by(id: device_id)
    return unless device&.garage_door? && device.state == "open"
    opened_at = Time.zone.parse(opened_at.to_s) if opened_at.is_a?(String)
    return unless device.deviceable.updated_at.to_i == opened_at.to_i  # it moved since; a newer check is coming
    household = device.household
    Current.household = household
    Time.use_zone(household.time_zone) do
      return if household.home_alerts.where(kind: "garage_open", device: device).where("created_at >= ?", opened_at).where.not(acknowledged_at: nil).exists?
      minutes = ((Time.current - opened_at) / 60).round
      household.home_alerts.create!(kind: "garage_open", device: device, message: "Garage open for #{minutes} min · #{whereabouts(household)}")
      self.class.set(wait: AFTER).perform_later(device_id, opened_at)
    end
  ensure
    Current.household = nil
  end

  private

  # "Wes is 12 min away" for the nearest adult on the way home, else who is home.
  def whereabouts(household)
    adults = household.people.reject(&:kid?)
    away = adults.select { |p| !p.home? && p.eta_minutes }.min_by(&:eta_minutes)
    return "#{away.name} is #{away.eta_minutes} min away" if away
    adults.any?(&:home?) ? "Someone is home" : "No one is home"
  end
end
