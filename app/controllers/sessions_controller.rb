class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create verify confirm]
  # Codes are six digits with a ten-minute life; the forms get ten tries every few minutes
  # (plan: Second gap review).
  rate_limit to: 10, within: 3.minutes, only: %i[create confirm],
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  # Step 1: ask for email
  def new; end

  # Step 1 submit: issue + email a code, to members only (plan: Decisions, sign-in).
  def create
    unless Current.household.nil? || Current.household.login_allowed?(params[:email])
      return redirect_to new_session_path, alert: "That address is not a member of this household. An adult can add it in Settings."
    end
    identity = Identity.find_or_create_by(email: params[:email])
    code = identity.issue_login_code!
    LoginMailer.code(identity, code).deliver_later
    redirect_to verify_session_path(identity_id: identity.id), notice: "We emailed you a 6-digit code."
  end

  # Step 2: enter the code
  def verify
    @identity = Identity.find(params[:identity_id])
  end

  # Step 2 submit: check code, sign in
  def confirm
    identity = Identity.find(params[:identity_id])
    if identity.login_code_valid?(params[:code])
      identity.clear_login_code!
      user = identity.user || create_user_for(identity)
      link_member(user)
      sign_in(user)
      redirect_to root_path, notice: "Signed in."
    else
      redirect_to verify_session_path(identity_id: identity.id), alert: "Invalid or expired code."
    end
  end

  def destroy
    sign_out
    redirect_to new_session_path, notice: "Signed out."
  end

  private

  # The person with this login's email, linked at the first sign-in.
  def link_member(user)
    person = user.household.member_for(user)
    person.update!(user: user) if person && person.user != user
  end


  # First login creates the User and attaches it to the single tenant.
  # Self-heals if no tenant exists yet (starter convenience).
  # Adjust when you add real multi-tenant membership.
  def create_user_for(identity)
    Current.household ||= Household.first || Household.create!(name: "Default")
    User.create!(identity: identity, household: Current.household)
  end
end
