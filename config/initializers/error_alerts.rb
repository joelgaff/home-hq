# Unhandled exceptions become Telegram alerts (see Alerts::ErrorSubscriber for the rate limit).
Rails.application.config.after_initialize do
  Rails.error.subscribe(Alerts::ErrorSubscriber.new)
end
