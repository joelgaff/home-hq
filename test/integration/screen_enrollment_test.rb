require "test_helper"

# A screen (the wall frame) signs in once by opening its enrollment link; from then on it is
# recognised by a long-lived cookie, with no email or code involved.
class ScreenEnrollmentTest < ActionDispatch::IntegrationTest
  setup do
    @screen = Screen.create!(household: households(:primary), name: "Kitchen frame")
  end

  test "opening the enrollment link signs the screen in for a year" do
    get enroll_screen_path(@screen.enrollment_token)
    assert_redirected_to root_path

    cookie = response.headers["Set-Cookie"].to_s
    assert_match(/screen_token=/, cookie)
    expires = Time.httpdate(cookie[/expires=([^;]+)/, 1])
    assert_in_delta 1.year.from_now.to_i, expires.to_i, 1.day.to_i

    get root_path
    assert_response :success
    assert @screen.reload.enrolled?
  end

  test "an enrollment link works only once" do
    token = @screen.enrollment_token
    get enroll_screen_path(token)
    assert_redirected_to root_path

    reset!
    get enroll_screen_path(token)
    assert_response :not_found
  end

  test "an unknown enrollment token is not found" do
    get enroll_screen_path("nope")
    assert_response :not_found
  end

  test "a screen cookie that no longer matches a screen is ignored" do
    get enroll_screen_path(@screen.enrollment_token)
    @screen.destroy

    get root_path
    assert_redirected_to new_session_path
  end
end
