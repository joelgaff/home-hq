# Photos from Immich (plan: milestone 7): each household's chosen albums, plus "on this day" across
# the last fifteen years, become Photo rows the slideshow already knows (date, orientation, place,
# album, favourite). Photos gone from Immich go; the pool stays bounded; demo photos are untouched.
class PhotoSyncJob < ApplicationJob
  queue_as :default

  YEARS_BACK = 15
  POOL_CAP = 300

  def perform
    return unless Immich.configured?
    Household.find_each do |household|
      next if household.immich_album_ids.blank? && !household.photos.where.not(immich_id: nil).exists?
      Current.household = household
      Time.use_zone(household.time_zone) { sync(household) }
    rescue *Immich::FAILURES => e
      Rails.logger.warn "Photo sync for #{household.name} failed: #{e.message}"
    ensure
      Current.household = nil
    end
  end

  def sync(household)
    seen = []
    household.immich_album_ids.each do |album_id|
      album = Immich.album(album_id) or next
      Array(album["assets"]).each { |asset| seen << upsert(household, asset, album["albumName"]) }
    end
    today = Time.zone.today
    (1..YEARS_BACK).each do |years|
      day = today.prev_year(years) rescue next
      found = Immich.search(takenAfter: day.beginning_of_day.utc.iso8601, takenBefore: day.end_of_day.utc.iso8601, type: "IMAGE", size: 50)
      Array(found.dig("assets", "items")).each { |asset| seen << upsert(household, asset, "On this day") }
    end
    seen = seen.compact.uniq
    household.photos.where.not(immich_id: nil).where.not(id: seen).destroy_all
    overflow = household.photos.where.not(immich_id: nil).order(taken_on: :desc, id: :desc).offset(POOL_CAP)
    household.photos.where(id: overflow).destroy_all
  end

  private

  def upsert(household, asset, album_name)
    return nil unless asset["type"].to_s.casecmp?("IMAGE")
    exif = asset["exifInfo"] || {}
    taken = (asset["localDateTime"] || asset["fileCreatedAt"]).to_s[0, 10]
    return nil if taken.blank?
    w, h = exif["exifImageWidth"].to_i, exif["exifImageHeight"].to_i
    w, h = h, w if %w[5 6 7 8].include?(exif["orientation"].to_s)
    photo = household.photos.find_or_initialize_by(immich_id: asset["id"])
    photo.assign_attributes(image_key: "immich:#{asset['id']}", taken_on: Date.parse(taken),
      orientation: (w.positive? && h > w) ? "portrait" : "landscape",
      place: (exif["city"].presence && [ exif["city"], exif["state"] ].compact_blank.join(", ")),
      album: photo.persisted? && photo.album != "On this day" && album_name == "On this day" ? photo.album : album_name,
      favorite: asset["isFavorite"] == true)
    photo.save!
    photo.id
  end
end
