# A camera (ui-spec §1.6): mapped to a hub entity its snapshots come through us from Home
# Assistant's camera proxy (plan: milestone 6); a demo camera shows a placeholder image.
class Camera < ApplicationRecord
  include Positioned

  belongs_to :household
  has_many :home_alerts, dependent: :nullify

  validates :name, presence: true
  before_validation { place_last(household.cameras) if household }

  scope :in_order, -> { order(:position, :id) }

  def mapped? = entity_id.present?

  def hub?
    mapped? && HomeAssistant.configured?
  end

  def snapshot_url(width = 400, height = 250)
    mapped? ? Rails.application.routes.url_helpers.snapshot_camera_path(self) : placeholder_url(width, height)
  end

  def placeholder_url(width = 400, height = 250)
    "https://picsum.photos/seed/#{image_key.presence || id}/#{width}/#{height}"
  end
end
