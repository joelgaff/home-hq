namespace :home_assistant do
  desc "The bridge process: keeps a WebSocket to Home Assistant and applies its state changes (idles until configured)"
  task listen: :environment do
    Rails.logger = ActiveSupport::Logger.new($stdout) unless Rails.env.test?
    HomeAssistant::Listener.run
  end
end
