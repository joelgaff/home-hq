require "test_helper"

class AlertTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { Alert.notifier = @notifier = FakeNotifier.new }
  teardown { Alert.notifier = nil }

  test "deliver hands the text to a background job so callers never wait on Telegram" do
    assert_enqueued_with(job: AlertJob, args: [ "Disk almost full" ]) do
      Alert.deliver("Disk almost full")
    end
  end

  test "deliver_now sends through the notifier" do
    Alert.deliver_now("Disk almost full")
    assert_equal [ "Disk almost full" ], @notifier.sent
  end
end
