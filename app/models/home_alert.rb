# An alert from the house (plan: milestone 6; ui-spec §1.9): the doorbell, a package, a leak, the
# garage left open. Every screen hears it as an "alert" stream action (the takeover or banner);
# acknowledging it from the frame is kept and logged.
class HomeAlert < ApplicationRecord
  KINDS = %w[doorbell package leak garage_open].freeze
  # The alerts controller's names for them (ui-spec §1.9).
  SCREEN_KINDS = { "doorbell" => "doorbell", "package" => "package", "leak" => "leak", "garage_open" => "garage" }.freeze

  belongs_to :household
  belongs_to :camera, optional: true
  belongs_to :device, optional: true

  validates :kind, inclusion: KINDS

  scope :open, -> { where(acknowledged_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  after_create_commit :tell_the_screens

  def acknowledged? = acknowledged_at.present?

  def acknowledge!(by: nil)
    update!(acknowledged_at: Time.current, acknowledged_by: by)
    AuditEntry.record("alert.acknowledged", household: household, subject: self, subject_name: kind.tr("_", " "))
  end

  def screen_kind
    SCREEN_KINDS.fetch(kind)
  end

  private

  def tell_the_screens
    routes = Rails.application.routes.url_helpers
    attributes = { kind: screen_kind, "alert-id": id, message: message.to_s }
    attributes.merge!("camera-url": routes.camera_path(camera), "camera-snapshot": camera.snapshot_url(1280, 800)) if camera
    attributes["device-url"] = routes.device_path(device) if device
    Turbo::StreamsChannel.broadcast_action_to(household, action: "alert", attributes: attributes)
  end
end
