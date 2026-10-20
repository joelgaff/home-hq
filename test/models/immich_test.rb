require "test_helper"

# The Immich client (plan: Integrations: photos): the photo library on the home server. Off until
# a URL and API key are set; tests hand in a transport.
class ImmichTest < ActiveSupport::TestCase
  teardown { Immich.reset! }

  test "off until configured; then it calls the API with the key and fetches thumbnails" do
    assert_not Immich.configured?
    assert_nil Immich.albums
    Immich.configure(url: "http://immich.test:2283/", api_key: "immich-key")
    calls = []
    Immich.transport = lambda do |request|
      calls << request
      case request[:path]
      when "/api/albums" then [ 200, [ { "id" => "a1", "albumName" => "Family", "assetCount" => 2 } ] ]
      when "/api/assets/x1/thumbnail" then [ 200, "JPEG".b, "image/jpeg" ]
      else [ 404, { "message" => "not found" } ]
      end
    end
    assert_equal [ [ "Family", "a1", 2 ] ], Immich.albums.map { |a| [ a["albumName"], a["id"], a["assetCount"] ] }
    assert_equal [ "GET", "http://immich.test:2283/api/albums", "immich-key" ], [ calls[0][:method], calls[0][:url], calls[0][:headers]["x-api-key"] ]
    bytes, type = Immich.thumbnail("x1", size: "preview")
    assert_equal [ "JPEG", "image/jpeg", "size=preview" ], [ bytes, type, URI(calls[1][:url]).query ]
    assert_raises(Immich::Error) { Immich.get("/api/nothing") }
  end
end
