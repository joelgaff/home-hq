class Light < ApplicationRecord
  include SyncsPieces
  syncs_pieces :"control-rooms", :"control-sum", :"today-status", household: -> { device&.household }

  include Deviceable

  validates :level, inclusion: 0..100

  def self.snapshot_attributes = %i[on level]

  def state_label
    on? ? "#{level}%" : "Off"
  end

  def fill_percent
    on? ? level : 0
  end

  # {on: true, level: 55} / {on: false}: switching off keeps the level for the next tap (ui-spec §1.6).
  def apply(patch)
    patch = patch.to_h.symbolize_keys
    update!(patch.slice(:on, :level).compact)
  end

  # A scene level of 0 means off; anything else is on at that level.
  def apply_scene_level(value)
    value.zero? ? update!(on: false) : update!(on: true, level: value)
  end
end
