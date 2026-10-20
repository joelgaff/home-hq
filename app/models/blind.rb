class Blind < ApplicationRecord
  include SyncsPieces
  syncs_pieces :"control-rooms", :"control-sum", :"today-status", household: -> { device&.household }

  include Deviceable

  validates :position, inclusion: 0..100

  def self.snapshot_attributes = %i[position]

  def on? = position.positive?
  def fill_percent = position

  def state_label
    return "Closed" if position.zero?
    return "Open" if position == 100
    "#{position}% open"
  end

  def apply(patch)
    update!(position: patch.to_h.symbolize_keys.fetch(:position))
  end

  def apply_scene_level(value)
    update!(position: value)
  end
end
