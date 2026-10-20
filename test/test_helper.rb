ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

module ActiveSupport
  class TestCase
    # The cache backs rate limiting; every test starts with it empty.
    setup { Rails.cache.clear }

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)
    # A worker could hang on exit on ActionCable's threads (the system tests' live sync); stop
    # the cable server's connections, worker pool and event loop before the worker leaves.
    parallelize_teardown { |_worker| ActionCable.server.restart }

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    # Sign in through the real magic-link flow so tests exercise the same path people use.
    def sign_in_as(user)
      code = user.identity.issue_login_code!
      post confirm_session_path, params: { identity_id: user.identity.id, code: code }
      assert_redirected_to root_path
    end

    # The wall frame: an enrolled screen, which gets the frame layout (fixed stage, lanes).
    def show_on_screen(name: "Kitchen")
      screen = Screen.create!(household: households(:primary), name: name)
      get enroll_screen_path(screen.enrollment_token)
      assert_redirected_to root_path
      screen
    end
  end
end
