# A controllable thing in a room. The row carries what every device shares (name, room, order);
# the state lives on the delegated type (Light, Blind, DoorLock, GarageDoor). `apply` is the
# optimistic contract from ui-spec §1.6: it either lands the patch or refuses it, and the real
# Home Assistant bridge (milestone 5) must behave exactly the same way. `flaky` marks a device the
# mock bridge treats as unreachable.
class Device < ApplicationRecord
  include Positioned

  TYPES = %w[Light Blind DoorLock GarageDoor].freeze
  TYPE_LABELS = { "Light" => "Light or switch", "Blind" => "Blind", "DoorLock" => "Door lock", "GarageDoor" => "Garage door" }.freeze
  # Which hub domains each type is mapped from (plan: milestone 5).
  DOMAINS = { "Light" => %w[light switch], "Blind" => %w[cover], "DoorLock" => %w[lock], "GarageDoor" => %w[cover] }.freeze

  belongs_to :household
  belongs_to :room, optional: true
  delegated_type :deviceable, types: TYPES, dependent: :destroy
  has_many :scene_settings, dependent: :destroy

  validates :name, presence: true
  normalizes :entity_id, with: ->(e) { e.to_s.strip.presence }
  validates :entity_id, uniqueness: { scope: :household_id, message: "is already mapped to another device" }, allow_nil: true
  before_validation { place_last(household.devices) if household }

  scope :in_order, -> { order(:position, :id) }
  scope :lights, -> { where(deviceable_type: "Light") }
  scope :locks, -> { where(deviceable_type: "DoorLock") }
  scope :garages, -> { where(deviceable_type: "GarageDoor") }

  delegate :state_label, :on?, :level, :position, :locked?, :state, :secure?, :warn?, :fill_percent, :kind,
    :snapshot, :restore, to: :deviceable

  # Lands a state change (returns true) or refuses it when the device cannot be reached (false,
  # nothing changes). Patches are per type: {on:, level:}, {position:}, {locked:}, {state:}. A
  # mapped device asks the hub first (HomeAssistant::Commands); a demo one follows `flaky`.
  def apply(patch = {}, audit: true, **keywords)
    patch = patch.to_h.symbolize_keys.merge(keywords)
    if hub?
      return false unless HomeAssistant::Commands.device(self, patch)
    elsif flaky?
      return false
    end
    deviceable.apply(patch)
    audit(patch) if audit
    true
  end

  # The doorbell takeover's unlock (plan: milestone 6): open now, relock in two minutes.
  RELOCK_AFTER = 2.minutes

  def unlock_for_a_while!(adult: nil)
    Current.pin_person ||= adult
    return false unless apply(locked: false)
    RelockJob.set(wait: RELOCK_AFTER).perform_later(id)
    true
  end

  # Locks and the garage go in the audit log (plan: second gap review).
  def audit(patch)
    action = if door_lock? && patch.key?(:locked) then patch[:locked] ? "device.locked" : "device.unlocked"
    elsif garage_door? && patch[:state] == "opening" then "device.garage_opened"
    end
    AuditEntry.record(action, household: household, subject: self) if action
  end

  # Driven by the hub: mapped, and the hub is connected.
  def hub?
    mapped? && HomeAssistant.configured?
  end

  def type_label
    TYPE_LABELS[deviceable_type]
  end

  def mapped?
    entity_id.present?
  end

  def dom_id_for_tile
    "device_#{id}"
  end
end
