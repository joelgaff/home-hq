require "test_helper"

# The login pages (plan: milestone 2 "logins"): the same paper-and-ink look as the dashboard,
# phone-friendly, one field per step.
class LoginPagesTest < ActionDispatch::IntegrationTest
  test "the email step is styled and phone-sized" do
    get new_session_path
    assert_response :success
    assert_select "meta[name=viewport][content*='width=device-width']", 1
    assert_select "link[rel=stylesheet][href*='dashboard/pages']", 1
    assert_select "main.page form.page-form input[type=email][autocomplete=email]", 1
    assert_select "main.page h1.serif", /Sign in/
    assert_select "main.page .page-brand", /Home HQ/
  end

  test "the code step keeps the numeric keypad and shows the address" do
    identity = identities(:owner)
    get verify_session_path(identity_id: identity.id)
    assert_select "main.page form.page-form input[inputmode=numeric][autocomplete=one-time-code]", 1
    assert_select "main.page p.page-note", /owner@example.com/
  end
end
