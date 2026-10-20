require "net/http"

module Alerts
  # Sends operational alerts to the household's Telegram chat through a bot. Unconfigured, it does
  # nothing (the app runs with zero integrations); failing, it logs and answers false, never raises.
  class Telegram
    TIMEOUT = 5 # seconds

    # The default HTTP call: POST JSON with short timeouts.
    HTTP = lambda do |uri, body|
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.post(uri.path, body, "Content-Type" => "application/json")
      end
    end

    def initialize(bot_token: self.class.setting(:bot_token), chat_id: self.class.setting(:chat_id), client: HTTP)
      @bot_token, @chat_id, @client = bot_token, chat_id, client
    end

    def configured?
      @bot_token.present? && @chat_id.present?
    end

    def deliver(text)
      return warn_unconfigured unless configured?

      response = @client.call(uri, { chat_id: @chat_id, text: text }.to_json)
      response.is_a?(Net::HTTPSuccess) || log_failure("Telegram answered #{response.code}")
    rescue StandardError => error
      log_failure(error.message)
    end

    class << self
      attr_accessor :warned

      def setting(name)
        Rails.application.credentials.dig(:telegram, name).presence || ENV["TELEGRAM_#{name.to_s.upcase}"].presence
      end
    end

    private

    def uri
      URI("https://api.telegram.org/bot#{@bot_token}/sendMessage")
    end

    def warn_unconfigured
      unless self.class.warned
        Rails.logger.info "Telegram alerts are off: set telegram.bot_token and telegram.chat_id in credentials."
        self.class.warned = true
      end
      false
    end

    def log_failure(reason)
      Rails.logger.warn "Telegram alert not sent: #{reason}"
      false
    end
  end
end
