module Authentication
  extend ActiveSupport::Concern

  SCREEN_COOKIE = :screen_token
  SCREEN_SESSION_LENGTH = 1.year

  included do
    before_action :require_login
    helper_method :current_user, :current_screen, :logged_in?
  end

  private

  def current_user
    Current.user ||= User.find_by(id: session[:user_id])
  end

  # The device showing the dashboard, when the request comes from an enrolled screen.
  def current_screen
    Current.screen ||= Screen.find_by(session_token: cookies.signed[SCREEN_COOKIE]) if cookies.signed[SCREEN_COOKIE]
  end

  def logged_in?
    current_user.present? || current_screen.present?
  end

  def require_login
    redirect_to new_session_path, alert: "Please sign in." unless logged_in?
  end

  # For pages only a person may use (settings, managing screens): a screen is refused, not redirected.
  def require_user
    return if current_user.present?
    return head :forbidden if current_screen.present?
    redirect_to new_session_path, alert: "Please sign in."
  end

  # Settings and screens are for adults: a kid's login (a person marked kid) is refused. A login
  # with no person yet counts as an adult (the owner before adding themselves).
  def require_adult
    require_user
    return if performed?
    head :forbidden if current_user.person&.kid?
  end

  def allow_unauthenticated
    skip_before_action :require_login, raise: false
  end

  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    Current.user = user
  end

  def sign_in_screen(screen)
    cookies.signed[SCREEN_COOKIE] = {
      value: screen.session_token, expires: SCREEN_SESSION_LENGTH.from_now, httponly: true, same_site: :lax
    }
    Current.screen = screen
  end

  def sign_out
    reset_session
    cookies.delete(SCREEN_COOKIE)
    Current.user = nil
    Current.screen = nil
  end
end
