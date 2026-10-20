# Opened once on the device itself: spends the enrollment token and leaves the screen cookie.
class ScreenEnrollmentsController < ApplicationController
  skip_before_action :require_login

  def create
    screen = Screen.enrollable.find_by!(enrollment_token: params[:token])
    screen.enroll!
    sign_in_screen(screen)
    redirect_to root_path
  end
end
