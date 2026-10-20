require "test_helper"

# Immich photos on the screens (plan: milestone 7): the image comes through us (the frame has no
# Immich key), a favourite toggled on the frame is a favourite in Immich, and Settings picks the
# albums.
class PhotoImageTest < ActionDispatch::IntegrationTest
  setup do
    show_on_screen
    @photo = households(:primary).photos.create!(immich_id: "x1", image_key: "immich:x1", taken_on: Date.new(2024, 6, 1), orientation: "landscape", album: "Family")
    Immich.configure(url: "http://immich.test:2283", api_key: "k")
    @calls = []
    Immich.transport = lambda do |request|
      @calls << request
      case request[:path]
      when "/api/assets/x1/thumbnail" then [ 200, "JPEG".b, "image/jpeg" ]
      when "/api/assets" then [ 200, [] ]
      else [ 404, {} ]
      end
    end
  end

  teardown { Immich.reset! }

  test "the image is proxied at two sizes with a day of browser caching; a demo photo has none" do
    get image_photo_path(@photo)
    assert_response :success
    assert_equal [ "image/jpeg", "JPEG" ], [ response.media_type, response.body ]
    assert_match(/max-age=86400/, response.headers["Cache-Control"])
    assert_equal "size=preview", URI(@calls.last[:url]).query
    get image_photo_path(@photo, size: "small")
    assert_equal "size=thumbnail", URI(@calls.last[:url]).query
    get image_photo_path(photos(:tofino))
    assert_response :not_found
  end

  test "favouriting on the frame favourites in Immich too" do
    patch photo_path(@photo), params: { favorite: true }, as: :turbo_stream
    assert_response :success
    assert @photo.reload.favorite?
    put_call = @calls.find { |c| c[:method] == "PUT" && c[:path] == "/api/assets" }
    assert_equal({ "ids" => [ "x1" ], "isFavorite" => true }, put_call[:body])
  end

  test "Settings → Integrations shows Immich's albums to pick and a sync button" do
    reset!
    sign_in_as users(:owner)
    Immich.transport = ->(_r) { [ 200, [ { "id" => "a1", "albumName" => "Family", "assetCount" => 12 }, { "id" => "a2", "albumName" => "Kids", "assetCount" => 3 } ] ] }
    get settings_path
    assert_select "p", text: /Immich is connected/i
    assert_select "input[name='household[immich_album_ids][]'][value=a1]", 1
    assert_select "input[name='household[immich_album_ids][]'][value=a2]", 1
    assert_select "form[action=?]", sync_settings_photos_path
    patch settings_path, params: { household: { immich_album_ids: [ "", "a2" ] } }
    assert_equal [ "a2" ], households(:primary).reload.immich_album_ids
    delete settings_photos_path
    assert_equal 0, households(:primary).photos.where(immich_id: nil).count, "the demo photos can be cleared"
    assert_equal 1, households(:primary).photos.where.not(immich_id: nil).count
  end
end
