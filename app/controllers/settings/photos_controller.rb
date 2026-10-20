# Settings → Integrations, photos (plan: milestone 7): sync Immich now, or clear the demo photos.
class Settings::PhotosController < Settings::BaseController
  def sync
    PhotoSyncJob.perform_now
    saved(settings_path, "Photos synced: #{@household.photos.where.not(immich_id: nil).count} from Immich.")
  end

  def destroy
    @household.photos.where(immich_id: nil).destroy_all
    saved(settings_path, "The demo photos are gone.")
  end
end
