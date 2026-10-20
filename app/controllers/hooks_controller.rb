# Inbound webhooks (plan: milestone 6): Home Assistant automations post an alert with the shared
# secret in X-Hook-Secret. No session, no CSRF; the secret is the whole of the authentication.
class HooksController < ApplicationController
  skip_before_action :require_login
  skip_forgery_protection

  def home_assistant
    return head :unauthorized unless secret_ok?
    kind = params[:kind].to_s
    return head :unprocessable_entity unless HomeAlert::KINDS.include?(kind)
    household = Current.household
    alert = household.home_alerts.create!(kind: kind, message: params[:message].presence,
      camera: household.cameras.find_by(entity_id: params[:camera].to_s.presence),
      device: household.devices.find_by(entity_id: params[:device].to_s.presence),
      details: params.fetch(:details, {}).to_unsafe_h.slice(*%w[entity state zone]))
    render json: { id: alert.id }, status: :created
  end

  private

  def secret_ok?
    expected = HomeAssistant.webhook_secret.to_s
    given = request.headers["X-Hook-Secret"].to_s
    expected.present? && given.present? && ActiveSupport::SecurityUtils.secure_compare(expected, given)
  end
end
