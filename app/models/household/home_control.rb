# Rooms, devices, scenes, climate, media and cameras, plus the summaries the Today card and the
# Home control header show (ui-spec §1.1, §1.6).
module Household::HomeControl
  extend ActiveSupport::Concern

  included do
    has_many :rooms, -> { in_order }, dependent: :destroy
    has_many :devices, -> { in_order }, dependent: :destroy
    has_many :scenes, -> { in_order }, dependent: :destroy
    has_many :scene_activations, dependent: :destroy
    has_one :thermostat, dependent: :destroy
    has_one :media_player, dependent: :destroy
    has_many :cameras, -> { in_order }, dependent: :destroy
    # The scene highlighted on Home control until a manual change (ui-spec §1.6).
    belongs_to :active_scene, class_name: "Scene", optional: true
  end

  # "Turn everything off": records a snapshot of the lights that were on, like a scene would.
  def lights_off!
    on = lights_on
    activation = scene_activations.create!(snapshot: on.to_h { |d| [ d.id, d.snapshot ] })
    on.each { |d| d.deviceable.update!(on: false) }
    update!(active_scene: nil)
    AuditEntry.record("lights.off", household: self, details: { "count" => on.size })
    [ activation, on ]
  end

  def lock_all!
    locks = devices.locks.includes(:deviceable).to_a
    locks.each { |d| d.deviceable.update!(locked: true) }
    AuditEntry.record("locks.all", household: self)
    locks
  end

  # What the Today card and the Home control header say about the house, from one load of the
  # devices: a view asks for it once per piece and reads every line off it.
  Status = Struct.new(:lights_on, :unlocked_doors, :garage) do
    def rooms_lit
      lights_on.map(&:room_id).uniq
    end

    def secure?
      unlocked_doors.empty? && (garage.nil? || garage.secure?)
    end

    def garage_open?
      garage.present? && !garage.secure?
    end

    # "All locked" | "Garage open" | "{door} unlocked" (ui-spec §1.1)
    def security_line
      return "All locked" if secure?
      return "Garage open" if garage_open?
      "#{unlocked_doors.first.name} unlocked"
    end

    # Control header: "Locked / All doors + garage" or a count + names (ui-spec §1.6).
    def security_summary
      return [ "Locked", "All doors + garage" ] if secure?
      parts = []
      parts << "Garage #{garage.state}" if garage_open?
      parts << unlocked_doors.map(&:name).join(", ") if unlocked_doors.any?
      [ (unlocked_doors.size + (garage_open? ? 1 : 0)).to_s, parts.join(" · ") + " open" ]
    end
  end

  # Settings → Home "Clear": the demo (or any) home goes, so the real one can be mapped.
  def clear_home!
    transaction do
      update!(active_scene: nil)
      scene_activations.delete_all
      scenes.destroy_all
      devices.destroy_all
      thermostat&.destroy
      media_player&.destroy  # before the rooms: it points at one
      cameras.destroy_all
      rooms.destroy_all
      reload
    end
  end

  # Settings → Home "Import": every light, switch, lock and cover the hub knows and nothing here
  # is mapped to becomes a device (named as the hub names it, in no room), the first climate
  # entity the thermostat, the first media player the player, every camera a camera. Returns
  # the counts. Idempotent: mapped entities are skipped.
  def import_from_hub!
    states = Array(HomeAssistant.states)
    unit = HomeAssistant.temperature_unit
    counts = Hash.new(0)
    mapped = devices.where.not(entity_id: nil).pluck(:entity_id).to_set
    transaction do
      states.each do |s|
        id, domain, attrs = s["entity_id"].to_s, s["entity_id"].to_s.split(".").first, s["attributes"] || {}
        name = attrs["friendly_name"].presence || id
        case domain
        when "light", "switch", "lock", "cover"
          next if mapped.include?(id)
          devices.create!(name: name, entity_id: id, deviceable: HomeAssistant::StateSync.typed_for(domain, s))
          counts[:devices] += 1
        when "climate"
          next if thermostat&.entity_id.present?
          attributes = { entity_id: id, current_temperature: convert_temperature(attrs["current_temperature"] || 20, from: unit),
                         target_temperature: convert_temperature(attrs["temperature"] || 20, from: unit), humidity: attrs["current_humidity"],
                         mode: HomeAssistant::StateSync.hvac_mode(s["state"]) }
          thermostat ? thermostat.update!(attributes) : create_thermostat!(attributes)
          counts[:climate] += 1
        when "media_player"
          next if media_player&.entity_id.present?
          attributes = { entity_id: id, title: attrs["media_title"], artist: attrs["media_artist"], playing: s["state"] == "playing" }
          media_player ? media_player.update!(attributes) : create_media_player!(attributes)
          counts[:media] += 1
        when "camera"
          next if cameras.exists?(entity_id: id)
          cameras.create!(name: name, entity_id: id)
          counts[:cameras] += 1
        end
      end
    end
    counts
  end

  def home_status
    all = devices.includes(:deviceable).to_a
    Status.new(all.select { |d| d.light? && d.on? }, all.select { |d| d.door_lock? && !d.locked? }, all.find(&:garage_door?))
  end

  delegate :lights_on, :rooms_lit, :unlocked_doors, :garage, :secure?, :security_line, :security_summary, to: :home_status
end
