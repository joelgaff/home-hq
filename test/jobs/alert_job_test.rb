require "test_helper"

class AlertJobTest < ActiveJob::TestCase
  setup { Alert.notifier = @notifier = FakeNotifier.new }
  teardown { Alert.notifier = nil }

  test "sends the text now" do
    AlertJob.perform_now("Backup failed")
    assert_equal [ "Backup failed" ], @notifier.sent
  end
end
