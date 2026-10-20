require "test_helper"

# Adults register screens (the wall frames) from their own signed-in session and get the
# enrollment link to open on the device.
class ScreensTest < ActionDispatch::IntegrationTest
  test "an adult can register a screen and see its enrollment link" do
    sign_in_as users(:owner)

    assert_difference -> { Screen.count }, 1 do
      post screens_path, params: { screen: { name: "Kitchen frame" } }
    end
    screen = Screen.last
    assert_equal households(:primary), screen.household
    assert_redirected_to screen_path(screen)

    follow_redirect!
    assert_response :success
    assert_includes response.body, enroll_screen_url(screen.enrollment_token)
  end

  test "a screen's page stops showing the link once it is enrolled" do
    sign_in_as users(:owner)
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
    screen.enroll!

    get screen_path(screen)
    assert_response :success
    assert_not_includes response.body, "enroll"
    assert_includes response.body, "Enrolled"
  end

  test "an adult can revoke a screen" do
    sign_in_as users(:owner)
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")

    assert_difference -> { Screen.count }, -1 do
      delete screen_path(screen)
    end
    assert_redirected_to screens_path
  end

  test "signed-out visitors are sent to sign in" do
    get screens_path
    assert_redirected_to new_session_path
  end

  test "a screen itself cannot manage screens" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
    get enroll_screen_path(screen.enrollment_token)

    get screens_path
    assert_response :forbidden
  end
end
