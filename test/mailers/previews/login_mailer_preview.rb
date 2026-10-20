# Preview all emails at http://localhost:3000/rails/mailers/login_mailer
class LoginMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/login_mailer/code
  def code
    identity = Identity.first || Identity.new(email: "preview@example.com")
    LoginMailer.code(identity, "123456")
  end
end
