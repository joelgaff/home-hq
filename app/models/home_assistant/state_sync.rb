# Hub states → our rows (plan: milestone 5). Shared by the import, the listener and the refresh:
# what a hub entity's state means for a device of ours.
module HomeAssistant::StateSync
  IGNORED = %w[unavailable unknown].freeze

  module_function

  # One hub state onto whatever of ours is mapped to it (nothing when nothing is). Rows are
  # updated directly, never through `apply`, so no command goes back to the hub.
  def apply(household, state, mapped: nil)
    entity = state["entity_id"].to_s
    value = state["state"].to_s
    return if IGNORED.include?(value)
    attrs = state["attributes"] || {}
    device = (mapped ? mapped[:devices][entity] : household.devices.includes(:deviceable).find_by(entity_id: entity))
    if device
      apply_device(device, value, attrs)
    elsif (t = mapped ? mapped[:thermostat] : household.thermostat) && t.entity_id == entity
      t.update!(current_temperature: household.convert_temperature(attrs["current_temperature"], from: hub_unit) || t.current_temperature,
                target_temperature: household.convert_temperature(attrs["temperature"], from: hub_unit) || t.target_temperature,
                humidity: attrs["current_humidity"] || t.humidity, mode: hvac_mode(value))
    elsif (p = mapped ? mapped[:player] : household.media_player) && p.entity_id == entity
      p.update!(playing: value == "playing", title: attrs["media_title"].presence || p.title, artist: attrs["media_artist"].presence || p.artist)
    elsif (person = mapped ? mapped[:people][entity] : household.people.find_by(presence_entity: entity))
      apply_person(person, value, attrs)
    end
  end

  def apply_device(device, value, attrs)
    case device.kind
    when "light" then device.deviceable.update!(on: value == "on", **(attrs["brightness"] ? { level: level_from(attrs, value) } : {}))
    when "door_lock" then device.deviceable.update!(locked: value == "locked")
    when "blind" then device.deviceable.update!(position: (attrs["current_position"] || (value == "open" ? 100 : 0)).to_i.clamp(0, 100))
    when "garage_door" then device.deviceable.update!(state: value) if GarageDoor::STATES.include?(value)
    end
  end

  # home / not_home / a zone name → Home / Away / "At Office"; the position rides along for the ETA.
  def apply_person(person, value, attrs)
    whereabouts = case value
    when "home" then { home: true, status: "Home", eta_minutes: nil }
    when "not_home" then { home: false, status: "Away" }
    else { home: false, status: "At #{value}" }
    end
    person.update!(whereabouts.merge(presence_latitude: attrs["latitude"], presence_longitude: attrs["longitude"]))
  end

  # Every hub state onto our rows, in one broadcast.
  def refresh(household)
    states = HomeAssistant.states or return
    apply_many(household, states)
  end

  def apply_many(household, states)
    mapped = {
      devices: household.devices.where.not(entity_id: nil).includes(:deviceable).index_by(&:entity_id),
      thermostat: household.thermostat, player: household.media_player,
      people: household.people.where.not(presence_entity: nil).index_by(&:presence_entity)
    }
    Pieces.batch(origin: nil) { Array(states).each { |s| apply(household, s, mapped: mapped) } }
  end

  def hub_unit
    @hub_unit ||= HomeAssistant.temperature_unit
  end

  def forget_unit!
    @hub_unit = nil
  end

  # A new typed row for a hub entity of a mappable domain.
  def typed_for(domain, state)
    attrs = state["attributes"] || {}
    case domain
    when "light", "switch" then Light.new(on: state["state"] == "on", level: level_from(attrs, state["state"]))
    when "lock" then DoorLock.new(locked: state["state"] == "locked")
    when "cover"
      if garage?(attrs) then GarageDoor.new(state: GarageDoor::STATES.include?(state["state"]) ? state["state"] : "closed")
      else Blind.new(position: attrs["current_position"] || (state["state"] == "open" ? 100 : 0))
      end
    end
  end

  def garage?(attrs)
    %w[garage garage_door gate].include?(attrs["device_class"].to_s)
  end

  # Brightness 0..255 → percent; a switch (no brightness) is 100 when on.
  def level_from(attrs, state)
    return (attrs["brightness"].to_f / 255 * 100).round.clamp(1, 100) if attrs["brightness"]
    state == "on" ? 100 : 100
  end

  def hvac_mode(state)
    { "heat" => "heat", "cool" => "cool", "heat_cool" => "auto", "auto" => "auto", "off" => "off" }.fetch(state.to_s, "off")
  end
end
