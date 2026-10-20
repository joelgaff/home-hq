require "test_helper"

# Offline mode (plan: Offline and stale data): the service worker caches the shell and the last
# rendered page; the manifest makes the app installable.
class OfflineTest < ActionDispatch::IntegrationTest
  test "the service worker is served from the root scope" do
    get "/service-worker.js"
    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_match(/caches\.open/, response.body)
    assert_match(/data-offline-since/, response.body)
    assert_match(/mode === "navigate"/, response.body)
  end

  test "the frame's manifest names the app and asks for landscape fullscreen" do
    get "/manifest.json?layout=frame"
    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "Home HQ", manifest["name"]
    assert_equal "landscape", manifest["orientation"]
    assert_equal "fullscreen", manifest["display"]
    assert_equal "#F2EEE6", manifest["theme_color"]
  end

  test "the dashboard registers the worker and links the manifest" do
    sign_in_as users(:owner)
    get root_path
    assert_select "link[rel=manifest][href='/manifest.json']", 1
    assert_select "#stage[data-controller*=connection]", 1
  end
end
