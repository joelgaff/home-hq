require "test_helper"

# The dashboard is one page: the stage with its rail and every view already in the DOM (hidden
# with content-visibility), so switching tabs never loads a page (docs/ui-spec.md §0).
class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "an enrolled screen gets the dashboard shell with every view in the page" do
    screen = Screen.create!(household: households(:primary), name: "Kitchen")
    get enroll_screen_path(screen.enrollment_token)

    get root_path
    assert_response :success
    assert_select "#stage[data-mode=day]"
    assert_select "#rail .rail-item[data-go]", minimum: 6
    %w[home calendar tasks shopping photos control people].each do |view|
      assert_select "section.view#view-#{view}[data-view=#{view}]", 1
    end
    assert_select "#railClock"
    assert_select "#toasts"
    assert_select "#sheetLayer"
    assert_select "#takeover"
    assert_select "#ambient"
    assert_select "#night"
    assert_select "#demo"
  end

  test "the page carries the server's time for the clocks" do
    sign_in_as users(:owner)
    travel_to Time.zone.local(2026, 10, 14, 15, 18) do
      get root_path
    end
    assert_select "#stage[data-shell-now-value]" do |stage|
      assert_in_delta Time.zone.local(2026, 10, 14, 15, 18).to_f * 1000, stage.first["data-shell-now-value"].to_f, 1000
    end
  end

  test "nobody signed in is sent to the login page" do
    get root_path
    assert_redirected_to new_session_path
  end
  # Every piece on the page queries for itself, never per row: chores load once with their
  # routines and today's completions, devices once with their types (plan: milestone 3 tidy-up).
  test "the page renders in a bounded number of queries" do
    show_on_screen
    get root_path # warm the schema cache
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless %w[SCHEMA CACHE].include?(payload[:name]) || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
    end
    get root_path
    assert_response :success
    assert_operator count, :<=, 130, "the dashboard page ran #{count} queries"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
