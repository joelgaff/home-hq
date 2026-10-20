require "test_helper"

module Alerts
  class TelegramTest < ActiveSupport::TestCase
    # Stands in for the HTTP call: records what would be posted and answers with a canned response.
    class FakeClient
      attr_reader :calls

      def initialize(response = Net::HTTPOK.new("1.1", "200", "OK"))
        @response = response
        @calls = []
      end

      def call(uri, body)
        @calls << [ uri, body ]
        @response.is_a?(Exception) ? raise(@response) : @response
      end
    end

    test "posts the text to the bot's sendMessage endpoint for the chat" do
      client = FakeClient.new
      telegram = Telegram.new(bot_token: "123:abc", chat_id: "42", client: client)

      assert telegram.deliver("Hello from Home HQ")

      uri, body = client.calls.sole
      assert_equal "https://api.telegram.org/bot123:abc/sendMessage", uri.to_s
      assert_equal({ "chat_id" => "42", "text" => "Hello from Home HQ" }, JSON.parse(body))
    end

    test "is a no-op when unconfigured" do
      client = FakeClient.new
      telegram = Telegram.new(bot_token: nil, chat_id: nil, client: client)

      assert_not telegram.configured?
      assert_not telegram.deliver("Hello")
      assert_empty client.calls
    end

    test "reports failure instead of raising when Telegram answers with an error" do
      client = FakeClient.new(Net::HTTPBadRequest.new("1.1", "400", "Bad Request"))
      telegram = Telegram.new(bot_token: "123:abc", chat_id: "42", client: client)

      assert_not telegram.deliver("Hello")
    end

    test "reports failure instead of raising when the network is down" do
      client = FakeClient.new(Errno::ECONNREFUSED.new)
      telegram = Telegram.new(bot_token: "123:abc", chat_id: "42", client: client)

      assert_not telegram.deliver("Hello")
    end

    test "reads the token and chat from the environment when credentials are absent" do
      with_env("TELEGRAM_BOT_TOKEN" => "env:token", "TELEGRAM_CHAT_ID" => "7") do
        telegram = Telegram.new
        assert telegram.configured?
      end
    end

    private

    def with_env(values)
      previous = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
  end
end
