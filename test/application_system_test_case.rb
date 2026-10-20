require "test_helper"

# System tests drive the dashboard in a headless Chromium sized like the wall frame (1280×800).
# They exercise the Stimulus behaviours written from docs/ui-spec.md; the integration tests cover
# the server-rendered HTML.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  FRAME_SIZE = [ 1280, 800 ].freeze

  Selenium::WebDriver::Chrome.path = ENV.fetch("CHROME_BIN", "/usr/bin/chromium") if File.exist?(ENV.fetch("CHROME_BIN", "/usr/bin/chromium"))

  driven_by :selenium, using: :headless_chrome, screen_size: FRAME_SIZE do |options|
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
  end

  # The frame is signed in as a screen, not a person: enrol one and keep its cookie.
  def show_on_screen(name: "Kitchen")
    screen = Screen.create!(household: households(:primary), name: name)
    visit enroll_screen_path(screen.enrollment_token)
    fit_viewport_to_frame
    screen
  end

  PHONE_SIZE = [ 390, 844 ].freeze

  # A person on a phone: the window is phone-sized and the sign-in goes through the real
  # code-entry page (the code comes from the model, as the email would carry it).
  def sign_in_on_phone(user)
    fit_viewport_to(PHONE_SIZE)
    code = user.identity.issue_login_code!
    visit verify_session_path(identity_id: user.identity.id)
    fill_in "code", with: code
    click_on "Sign in"
    assert_selector "#stage[data-shell-ready]"
  end

  # `screen_size` sizes the window including its chrome, so the viewport comes out short and the
  # bottom of the stage (the rail clock) lands off-screen, which Selenium reports as invisible.
  def fit_viewport_to_frame
    fit_viewport_to(FRAME_SIZE)
  end

  def fit_viewport_to(target)
    visit "/up" unless page.current_url.start_with?("http")
    inner = evaluate_script("[innerWidth, innerHeight]")
    return if inner == target
    window = page.driver.browser.manage.window
    size = window.size
    window.resize_to(size.width + target[0] - inner[0], size.height + target[1] - inner[1])
  end
end
