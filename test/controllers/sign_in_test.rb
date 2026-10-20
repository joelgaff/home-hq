require "test_helper"

# Who may sign in (plan: Decisions, sign-in): the members an adult added in Settings, by the email
# on their person. The first login on an empty household bootstraps its owner; existing logins
# keep working without a person (a fresh start removes the people, not the logins); a kid with an
# email gets the app, not Settings; removing a person removes their login. The code form is rate
# limited.
class SignInTest < ActionDispatch::IntegrationTest
  test "an address that belongs to no member gets no code and no identity" do
    assert_no_changes -> { Identity.count } do
      assert_no_enqueued_emails do
        post session_path, params: { email: "stranger@example.com" }
      end
    end
    assert_redirected_to new_session_path
    assert_match(/not a member/i, flash[:alert])
  end

  test "a member's email gets a code, and the login links to the person on first sign-in" do
    people(:wes).update!(email: "wes@example.com")
    assert_enqueued_email_with LoginMailer, :code, args: ->(args) { args.first.email == "wes@example.com" } do
      post session_path, params: { email: "Wes@Example.com" }
    end
    identity = Identity.find_by!(email: "wes@example.com")
    assert_redirected_to verify_session_path(identity_id: identity.id)

    post confirm_session_path, params: { identity_id: identity.id, code: identity.issue_login_code! }
    assert_redirected_to root_path
    assert_equal identity.reload.user, people(:wes).reload.user
    get settings_path
    assert_response :success, "an adult member gets Settings"
  end

  test "existing logins keep working without a person, as after a fresh start" do
    assert_nil users(:owner).person
    post session_path, params: { email: "owner@example.com" }
    assert_redirected_to verify_session_path(identity_id: identities(:owner).id)
  end

  test "the first login on a household with no logins bootstraps the owner" do
    Person.update_all(user_id: nil)
    User.delete_all
    Identity.delete_all
    post session_path, params: { email: "first@example.com" }
    identity = Identity.find_by!(email: "first@example.com")
    assert_redirected_to verify_session_path(identity_id: identity.id)
    post confirm_session_path, params: { identity_id: identity.id, code: identity.issue_login_code! }
    assert_redirected_to root_path
    get settings_path
    assert_response :success
  end

  test "a kid with an email gets the app but not Settings" do
    people(:buzzsaw).update!(email: "buzz@example.com")
    post session_path, params: { email: "buzz@example.com" }
    identity = Identity.find_by!(email: "buzz@example.com")
    post confirm_session_path, params: { identity_id: identity.id, code: identity.issue_login_code! }
    assert_redirected_to root_path
    get root_path
    assert_response :success
    assert_select "body[data-layout=app]"
    get settings_path
    assert_response :forbidden
    get settings_people_path
    assert_response :forbidden
  end

  test "removing a person removes their login" do
    people(:wes).update!(email: "owner@example.com")
    assert_equal users(:owner), people(:wes).reload.user, "an existing login links as soon as the email is set"
    people(:wes).destroy
    assert_nil User.find_by(id: users(:owner).id)
    post session_path, params: { email: "owner@example.com" }
    assert_redirected_to new_session_path
  end

  test "setting a member's email sends them where to sign in" do
    assert_enqueued_email_with LoginMailer, :added, args: ->(args) { args.first == people(:claudia) } do
      people(:claudia).update!(email: "claudia@example.com")
    end
    mail = LoginMailer.added(people(:claudia))
    assert_equal [ "claudia@example.com" ], mail.to
    assert_match %r{https?://example\.com/session/new}, mail.text_part.body.to_s
    assert_no_enqueued_emails { people(:claudia).update!(name: "Claudia B.") }
  end

  test "the sign-in forms are rate limited" do
    identity = identities(:owner)
    10.times { post session_path, params: { email: "owner@example.com" } }
    post session_path, params: { email: "owner@example.com" }
    assert_redirected_to new_session_path
    assert_match(/too many/i, flash[:alert])
    Rails.cache.clear
    10.times { post confirm_session_path, params: { identity_id: identity.id, code: "000000" } }
    post confirm_session_path, params: { identity_id: identity.id, code: "000000" }
    assert_match(/too many/i, flash[:alert])
  end
end
