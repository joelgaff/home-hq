require "test_helper"
require "rake"

class AlertsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["alerts:test"].reenable
    Alert.notifier = @notifier = FakeNotifier.new
  end

  teardown { Alert.notifier = nil }

  test "alerts:test sends the check message now" do
    out, _err = capture_io { Rake::Task["alerts:test"].invoke }
    assert_equal [ "Home HQ alerts are working" ], @notifier.sent
    assert_match(/Sent/, out)
  end
end
