# Favourites (ui-spec §1.5) and, for Immich photos, the image itself through us (plan: milestone 7).
class PhotosController < ApplicationController
  def update
    photo = Current.household.photos.find(params[:id])
    favorite = ActiveModel::Type::Boolean.new.cast(params[:favorite])
    photo.update!(favorite: favorite)
    if photo.immich?
      begin
        Immich.favorite!([ photo.immich_id ], favorite)
      rescue *Immich::FAILURES => e
        Rails.logger.warn "Immich favourite for #{photo.immich_id} failed: #{e.message}"
      end
    end
    @toast = favorite ? { html: "Added to favourites · it’ll show up more often", icon: "heart", ms: 2500 }
                      : { html: "Removed from favourites", icon: "heart", ms: 2500 }
    render turbo_stream: turbo_stream.update("toasts", partial: "toasts/toast", locals: @toast)
  end

  # The preview (or the thumbnail, size=small) of an Immich photo, with a day of browser caching;
  # demo photos link to their placeholders directly.
  def image
    photo = Current.household.photos.find(params[:id])
    return head :not_found unless photo.immich? && Immich.configured?
    bytes, type = Immich.thumbnail(photo.immich_id, size: params[:size] == "small" ? "thumbnail" : "preview")
    expires_in 1.day, public: false
    send_data bytes, type: type, disposition: "inline"
  rescue *Immich::FAILURES => e
    Rails.logger.warn "Immich image for #{photo&.immich_id} failed: #{e.message}"
    head :service_unavailable
  end
end
