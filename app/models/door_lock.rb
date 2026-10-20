class DoorLock < ApplicationRecord
  include SyncsPieces
  syncs_pieces :"control-rooms", :"control-sum", :"today-status", household: -> { device&.household }

  include Deviceable

  def self.snapshot_attributes = %i[locked]

  def secure? = locked?
  def warn? = !locked?

  def state_label
    locked? ? "Locked" : "Unlocked"
  end

  def apply(patch)
    update!(locked: patch.to_h.symbolize_keys.fetch(:locked))
  end
end
