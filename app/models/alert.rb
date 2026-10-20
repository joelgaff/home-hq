# The app's one way to tell the owner something operational happened (deploys, errors, backups).
# `deliver` goes through a job so the caller never waits on the network.
class Alert
  class << self
    # Swap the destination (tests do); nil means the configured Telegram bot.
    attr_writer :notifier

    def deliver(text)
      AlertJob.perform_later(text)
    end

    def deliver_now(text)
      notifier.deliver(text)
    end

    def notifier
      @notifier || Alerts::Telegram.new
    end
  end
end
