require "test_helper"

# Photos from Immich (plan: milestone 7): the household's chosen albums plus "on this day" across
# the years become Photo rows the slideshow already knows how to show; favourites and places
# ride along; photos gone from Immich go; the pool stays bounded.
class PhotoSyncJobTest < ActiveJob::TestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    @household.update!(immich_album_ids: [ "a1" ])
    Immich.configure(url: "http://immich.test:2283", api_key: "k")
    @asset = lambda do |id, taken, w: 4000, h: 3000, fav: false, city: "Banff"|
      { "id" => id, "type" => "IMAGE", "localDateTime" => taken, "isFavorite" => fav,
        "exifInfo" => { "exifImageWidth" => w, "exifImageHeight" => h, "city" => city, "state" => "AB", "orientation" => nil } }
    end
    @album_assets = [ @asset.call("x1", "2024-06-01T10:00:00.000Z"), @asset.call("x2", "2025-01-02T10:00:00.000Z", w: 3000, h: 4000, fav: true) ]
    @memory_assets = [ @asset.call("m1", "2019-10-14T09:00:00.000Z", city: nil) ]
    Immich.transport = lambda do |request|
      case request[:path]
      when "/api/albums/a1" then [ 200, { "id" => "a1", "albumName" => "Family", "assets" => @album_assets } ]
      when "/api/search/metadata" then [ 200, { "assets" => { "items" => (request[:body]["takenAfter"].to_s.start_with?("2019") ? @memory_assets : []), "nextPage" => nil } } ]
      else [ 404, {} ]
      end
    end
  end

  teardown { Immich.reset! }

  test "album photos and on-this-day photos become rows with date, orientation, place, album and favourite" do
    PhotoSyncJob.perform_now
    photos = @household.photos.where.not(immich_id: nil).index_by(&:immich_id)
    assert_equal %w[m1 x1 x2], photos.keys.sort
    x2 = photos["x2"]
    assert_equal [ Date.new(2025, 1, 2), "portrait", "Banff, AB", "Family", true ], [ x2.taken_on, x2.orientation, x2.place, x2.album, x2.favorite ]
    assert_equal [ "landscape", nil, "On this day" ], [ photos["m1"].orientation, photos["m1"].place, photos["m1"].album ]
    assert photos["m1"].on_this_day?
    assert_equal "/photos/#{x2.id}/image", x2.url
    assert_equal "/photos/#{x2.id}/image?size=small", x2.url(:small)
  end

  test "photos gone from Immich go; demo photos are untouched; syncing twice adds nothing" do
    PhotoSyncJob.perform_now
    demo = @household.photos.where(immich_id: nil).count
    @album_assets.pop
    PhotoSyncJob.perform_now
    assert_equal %w[m1 x1], @household.photos.where.not(immich_id: nil).pluck(:immich_id).sort
    assert_equal demo, @household.photos.where(immich_id: nil).count
  end

  test "nothing happens without Immich or without albums; the job is on the schedule" do
    Immich.reset!
    PhotoSyncJob.perform_now
    assert_equal 0, @household.photos.where.not(immich_id: nil).count
    entry = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]["photo_sync"]
    assert_equal "PhotoSyncJob", entry["class"]
  end
end
