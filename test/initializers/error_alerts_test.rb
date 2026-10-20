require "test_helper"

class ErrorAlertsTest < ActiveSupport::TestCase
  test "the error subscriber is wired into Rails.error" do
    subscribers = Rails.error.instance_variable_get(:@subscribers)
    assert subscribers.any? { |subscriber| subscriber.is_a?(Alerts::ErrorSubscriber) }
  end
end
