# Our writes → hub service calls (plan: milestone 5; ui-spec §1.6 optimistic contract). Each
# command answers true when the hub took it and false when it refused or could not be reached;
# the caller then lands or refuses the patch. Unmapped things never get here.
module HomeAssistant::Commands
  FAILURES = HomeAssistant::FAILURES

  module_function

  def device(device, patch)
    entity = device.entity_id
    domain = entity.split(".").first
    case device.kind
    when "light"
      if patch.key?(:on) ? patch[:on] : device.on?
        data = { entity_id: entity }
        data[:brightness_pct] = patch[:level].to_i.clamp(1, 100) if domain == "light" && patch[:level]
        call(domain, "turn_on", data)
      else
        call(domain, "turn_off", entity_id: entity)
      end
    when "door_lock" then call("lock", patch[:locked] ? "lock" : "unlock", entity_id: entity)
    when "blind" then call("cover", "set_cover_position", entity_id: entity, position: patch[:position].to_i.clamp(0, 100))
    when "garage_door"
      case patch[:state]
      when "opening" then call("cover", "open_cover", entity_id: entity)
      when "closing" then call("cover", "close_cover", entity_id: entity)
      else true  # the final states come back from the hub
      end
    else true
    end
  end

  def thermostat_temperature(thermostat, target)
    value = thermostat.household.temperature_in(target, HomeAssistant.temperature_unit)
    call("climate", "set_temperature", entity_id: thermostat.entity_id, temperature: value)
  end

  def thermostat_mode(thermostat, mode)
    call("climate", "set_hvac_mode", entity_id: thermostat.entity_id, hvac_mode: { "auto" => "heat_cool" }.fetch(mode, mode))
  end

  def media_play(player, playing)
    call("media_player", playing ? "media_play" : "media_pause", entity_id: player.entity_id)
  end

  def scene_on(scene)
    call(scene.entity_id.split(".").first, "turn_on", entity_id: scene.entity_id)
  end

  def call(domain, service, data)
    HomeAssistant.call(domain, service, data)
    true
  rescue *FAILURES => e
    Rails.logger.warn "Home Assistant #{domain}.#{service} failed: #{e.message}"
    false
  end
end
