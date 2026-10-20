module Alerts
  # Turns unhandled exceptions reported to Rails.error into alerts, at most one per error class
  # every WINDOW so a crash loop sends one message, not hundreds.
  class ErrorSubscriber
    WINDOW = 10.minutes

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    def report(error, handled:, severity:, context:, source: nil)
      return if handled
      return unless first_in_window?(error)

      Alert.deliver("Error: #{error.class}: #{error.message.to_s.truncate(300)}")
    end

    private

    def first_in_window?(error)
      @cache.write("alerts/errors/#{error.class.name}", true, expires_in: WINDOW, unless_exist: true)
    end
  end
end
