# "Hold to shut off water" on the leak takeover (ui-spec §1.9; plan: milestone 6): closes the
# household's water valve through the hub, when one is mapped.
class WaterValvesController < ApplicationController
  def close
    household = Current.household
    entity = household.water_valve_entity.to_s
    return head :not_found if entity.blank? || !HomeAssistant.configured?
    domain = entity.split(".").first
    service = domain == "valve" ? "close_valve" : "turn_off"
    HomeAssistant.call(domain, service, { entity_id: entity })
    AuditEntry.record("valve.closed", household: household, subject_name: "water main")
    head :no_content
  rescue *HomeAssistant::FAILURES => e
    Rails.logger.warn "Water valve close failed: #{e.message}"
    head :service_unavailable
  end
end
