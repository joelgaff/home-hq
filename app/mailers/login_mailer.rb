class LoginMailer < ApplicationMailer
  def code(identity, code)
    @code = code
    mail to: identity.email, subject: "Your login code: #{code}"
  end

  # An adult added this person's email in Settings: where to sign in, and that there is no password.
  def added(person)
    @person = person
    @household = person.household
    mail to: person.email, subject: "You're on #{@household.name}'s Home HQ"
  end
end
