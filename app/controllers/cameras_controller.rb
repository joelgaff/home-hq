# The large camera sheet (ui-spec §1.6).
class CamerasController < ApplicationController
  def show
    @camera = Current.household.cameras.find(params[:id])
    render partial: "cameras/sheet", layout: false
  end

  # A mapped camera's image through the hub (the frame has no hub token), cached a few seconds
  # so a wall of screens asking every 20 s is one request to the camera; a demo camera's
  # placeholder otherwise.
  def snapshot
    camera = Current.household.cameras.find(params[:id])
    return head :not_found unless camera.hub?  # demo cameras link to their placeholder directly
    bytes, type = Rails.cache.fetch("camera-snapshot/#{camera.id}", expires_in: 15.seconds) { HomeAssistant.camera_image(camera.entity_id) }
    expires_in 15.seconds, public: false
    send_data bytes, type: type, disposition: "inline"
  rescue *HomeAssistant::FAILURES => e
    Rails.logger.warn "Snapshot for #{camera&.name} failed: #{e.message}"
    head :service_unavailable
  end
end
