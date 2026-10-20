require "test_helper"

# The wall frame runs Android System WebView 106 and cannot be upgraded. Rails' default
# `allow_browser versions: :modern` answers it with 406 "Your browser is not supported" (found in
# the Milestone 1 spike, docs/spikes/frame-performance-2026-10-14.md), so the app must never
# gate on browser version.
class FrameBrowserTest < ActionDispatch::IntegrationTest
  FRAME_USER_AGENT = "Mozilla/5.0 (Linux; Android 6.0.1; PF1007L Build/MMB29M; wv) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/106.0.5249.126 Safari/537.36"

  test "the frame's WebView 106 is served, not told to upgrade" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")

    get enroll_screen_path(screen.enrollment_token), headers: { "User-Agent" => FRAME_USER_AGENT }
    assert_redirected_to root_path

    get root_path, headers: { "User-Agent" => FRAME_USER_AGENT }
    assert_response :success
  end
end
