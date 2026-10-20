require "test_helper"

# Camera snapshots through the hub (plan: milestone 6): a mapped camera's image comes from Home
# Assistant's camera proxy, through us (the frame has no hub token), cached for a few seconds;
# a demo camera keeps its placeholder.
class CameraSnapshotTest < ActionDispatch::IntegrationTest
  setup do
    show_on_screen
    @camera = households(:primary).cameras.create!(name: "Drive", entity_id: "camera.drive")
    HomeAssistant.configure(url: "http://ha.test:8123", token: "t")
    @calls = 0
    HomeAssistant.transport = lambda do |request|
      @calls += 1
      request[:path] == "/api/camera_proxy/camera.drive" ? [ 200, "JPEGBYTES".b, "image/jpeg" ] : [ 404, {} ]
    end
    Rails.cache.clear
  end

  teardown { HomeAssistant.reset! }

  test "a mapped camera's snapshot is proxied from the hub and cached briefly" do
    assert_equal snapshot_camera_path(@camera), @camera.snapshot_url
    get snapshot_camera_path(@camera)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal "JPEGBYTES", response.body
    get snapshot_camera_path(@camera)
    assert_equal 1, @calls, "the second request within the cache window does not ask the hub"
  end

  test "the camera tiles and the sheet use the proxy for mapped cameras and a placeholder otherwise" do
    get control_path
    assert_select "#control-cams img[src=?]", snapshot_camera_path(@camera)
    demo = cameras(:front)
    assert_match(/picsum/, demo.snapshot_url)
    get snapshot_camera_path(demo)
    assert_response :not_found
  end

  test "when the hub cannot be reached the snapshot answers 503" do
    HomeAssistant.transport = ->(_r) { raise Errno::ECONNREFUSED }
    get snapshot_camera_path(@camera)
    assert_response :service_unavailable
  end
end
