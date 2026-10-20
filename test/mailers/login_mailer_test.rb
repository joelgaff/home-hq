require "test_helper"

class LoginMailerTest < ActionMailer::TestCase
  test "code" do
    identity = Identity.create!(email: "code@example.com")
    mail = LoginMailer.code(identity, "123456")

    assert_equal "Your login code: 123456", mail.subject
    assert_equal [ "code@example.com" ], mail.to
    assert_match "123456", mail.html_part.body.to_s
    assert_match "123456", mail.text_part.body.to_s
  end

  test "mail comes from the configured sender, with a safe default" do
    mail = LoginMailer.code(Identity.create!(email: "code@example.com"), "123456")
    assert_equal [ "home-hq@localhost" ], mail.from
  end
end
