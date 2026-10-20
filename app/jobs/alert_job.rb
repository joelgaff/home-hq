class AlertJob < ApplicationJob
  queue_as :default

  def perform(text)
    Alert.deliver_now(text)
  end
end
