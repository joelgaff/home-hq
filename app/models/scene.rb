# A preset: per-device levels (0 = off, blinds a position); Away and Goodnight also lock every
# door. Activating one records a snapshot so the toast's Undo can put everything back.
class Scene < ApplicationRecord
  include Positioned

  belongs_to :household
  has_many :scene_settings, dependent: :destroy
  has_many :devices, through: :scene_settings

  validates :name, presence: true
  before_validation { place_last(household.scenes) if household }

  # The settings form's levels: { device_id => level }; a blank level drops the device.
  def levels=(hash)
    @pending_levels = hash.to_h
  end

  after_save do
    next if @pending_levels.nil?
    scene_settings.where.not(device_id: @pending_levels.keys.map(&:to_i)).destroy_all
    @pending_levels.each do |device_id, level|
      setting = scene_settings.find_or_initialize_by(device_id: device_id.to_i)
      level.to_s.strip.empty? ? setting.destroy : setting.update!(level: level.to_i.clamp(0, 100))
    end
    @pending_levels = nil
  end

  scope :in_order, -> { order(:position, :id) }

  def activate!
    transaction do
      touched = scene_settings.includes(device: :deviceable).map(&:device)
      touched += household.devices.locks.includes(:deviceable).to_a if locks_all?
      activation = household.scene_activations.create!(scene: self, snapshot: touched.uniq.to_h { |d| [ d.id, d.snapshot ] })
      scene_settings.each do |s|
        HomeAssistant::Commands.device(s.device, s.level.zero? ? { on: false, position: 0 } : { on: true, level: s.level, position: s.level }) if s.device.hub?
        s.device.deviceable.apply_scene_level(s.level)
      end
      household.devices.locks.each do |d|
        HomeAssistant::Commands.device(d, { locked: true }) if d.hub?
        d.deviceable.update!(locked: true)
      end if locks_all?
      HomeAssistant::Commands.scene_on(self) if entity_id.present? && HomeAssistant.configured?
      household.update!(active_scene: self)
      AuditEntry.record("scene.activated", household: household, subject: self)
      activation
    end
  end
end
