class ApplicationMailer < ActionMailer::Base
  # The sender is a setting (credentials mailersend.from), never a hard-coded address of ours.
  default from: -> { Rails.application.credentials.dig(:mailersend, :from).presence || "home-hq@localhost" }
  layout "mailer"
end
