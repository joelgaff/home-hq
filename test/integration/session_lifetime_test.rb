require "test_helper"

# Adults sign in rarely: a session lasts a year rather than ending with the browser.
class SessionLifetimeTest < ActionDispatch::IntegrationTest
  test "signing in sets a year-long session cookie" do
    identity = identities(:owner)
    code = identity.issue_login_code!

    post confirm_session_path, params: { identity_id: identity.id, code: code }
    assert_redirected_to root_path

    cookie = response.headers["Set-Cookie"].to_s
    assert_match(/_home_dashboard_session=/, cookie)
    expires = Time.httpdate(cookie[/expires=([^;]+)/, 1])
    assert_in_delta 1.year.from_now.to_i, expires.to_i, 1.day.to_i
  end
end
