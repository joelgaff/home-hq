require "websocket/driver"
require "socket"
require "openssl"

# The live link to the hub (plan: Integrations: Rails ↔ HA WebSocket API). One long-running
# process (`bin/rails home_assistant:listen`, the `bridge` role) authenticates, subscribes to
# state_changed, reads every state once, and applies each change to our rows through StateSync.
# It idles while the hub is not configured and reconnects with a backoff when the link drops.
class HomeAssistant::Listener
  def self.socket_url
    HomeAssistant.url.sub(/\Ahttp/, "ws") + "/api/websocket"
  end

  # Forever: a session per connection, a pause between them.
  def self.run(sleeper: Kernel.method(:sleep), logger: Rails.logger)
    backoff = 5
    loop do
      unless HomeAssistant.configured?
        sleeper.call(60)
        next
      end
      begin
        logger.info "Home Assistant listener connecting to #{socket_url}"
        new.session
        backoff = 5
      rescue *HomeAssistant::FAILURES, IOError, EOFError, SystemCallError, OpenSSL::SSL::SSLError, JSON::ParserError => e
        logger.warn "Home Assistant listener: #{e.message}; retrying in #{backoff}s"
        sleeper.call(backoff)
        backoff = [ backoff * 2, 300 ].min
      end
    end
  end

  def initialize(connection: nil)
    @connection = connection
  end

  # One connection's worth of messages, until the hub hangs up.
  def session
    conn = @connection || Connection.open(self.class.socket_url)
    while (raw = conn.read)
      message = JSON.parse(raw)
      case message["type"]
      when "auth_required" then conn.send({ type: "auth", access_token: HomeAssistant.token }.to_json)
      when "auth_invalid" then raise HomeAssistant::Error, "Home Assistant refused the token: #{message['message']}"
      when "auth_ok"
        conn.send({ id: 1, type: "subscribe_events", event_type: "state_changed" }.to_json)
        conn.send({ id: 2, type: "get_states" }.to_json)
      when "result"
        each_household { |h| HomeAssistant::StateSync.apply_many(h, message["result"]) } if message["id"] == 2 && message["success"]
      when "event"
        state = message.dig("event", "data", "new_state")
        each_household { |h| HomeAssistant::StateSync.apply(h, state) } if state
      end
    end
  ensure
    conn&.close
  end

  private

  def each_household
    Household.find_each do |household|
      Current.household = household
      Time.use_zone(household.time_zone) { yield household }
    ensure
      Current.household = nil
    end
  end

  # A WebSocket over TCP or TLS, read message by message (websocket-driver does the framing).
  class Connection
    attr_reader :url

    def self.open(url)
      new(url).tap(&:connect)
    end

    def initialize(url)
      @url = url
      @queue = Queue.new
      @closed = false
    end

    def connect
      uri = URI(url)
      tcp = TCPSocket.new(uri.host, uri.port || (uri.scheme == "wss" ? 443 : 80))
      @io = if uri.scheme == "wss"
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
        OpenSSL::SSL::SSLSocket.new(tcp, ctx).tap { |s| s.hostname = uri.host; s.sync_close = true; s.connect }
      else
        tcp
      end
      @driver = WebSocket::Driver.client(self)
      @driver.on(:message) { |e| @queue << e.data }
      @driver.on(:close) { @closed = true; @queue << nil }
      @driver.on(:error) { |e| @closed = true; @queue << nil }
      @driver.start
    end

    # websocket-driver writes frames through here.
    def write(data)
      @io.write(data)
    end

    def send(text)
      @driver.text(text)
    end

    # The next text message, nil when the connection is gone.
    def read
      loop do
        return @queue.pop unless @queue.empty?
        return nil if @closed
        @driver.parse(@io.readpartial(16_384))
      end
    rescue EOFError, IOError, SystemCallError
      nil
    end

    def close
      @driver&.close
      @io&.close
    rescue IOError, SystemCallError
      nil
    end
  end
end
