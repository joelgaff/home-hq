class GarageDoor < ApplicationRecord
  include SyncsPieces
  syncs_pieces :"control-rooms", :"control-sum", :"today-status", household: -> { device&.household }

  include Deviceable

  STATES = %w[closed open opening closing].freeze
  LABELS = { "closed" => "Closed", "open" => "Open", "opening" => "Opening…", "closing" => "Closing…" }.freeze

  validates :state, inclusion: STATES

  def self.snapshot_attributes = %i[state]

  # Left open? A check fifteen minutes after opening (plan: milestone 6).
  after_update_commit -> { GarageOpenCheckJob.set(wait: GarageOpenCheckJob::AFTER).perform_later(device.id, updated_at) if saved_change_to_state? && state == "open" && device }

  def secure? = state == "closed"
  def warn? = !secure?
  def moving? = state.end_with?("ing")

  def state_label
    LABELS[state]
  end

  def apply(patch)
    update!(state: patch.to_h.symbolize_keys.fetch(:state))
  end
end
