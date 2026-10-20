namespace :alerts do
  desc "Send a test alert to the configured Telegram chat, synchronously"
  task test: :environment do
    if Alert.deliver_now("Home HQ alerts are working")
      puts "Sent. Check the Telegram chat."
    else
      puts "Not sent. Set telegram.bot_token and telegram.chat_id in credentials (or TELEGRAM_BOT_TOKEN " \
           "and TELEGRAM_CHAT_ID), then check log/#{Rails.env}.log for the reason."
      exit 1
    end
  end
end
