require "net/http"

# The Home Assistant client (plan: Simplifications 2): the hub for weather, travel times and, from
# milestone 5, the house. Configured by `home_assistant.url` / `home_assistant.token` in the
# credentials or HOME_ASSISTANT_URL / HOME_ASSISTANT_TOKEN; off (every call answers nil) until
# then, so the app runs with no integrations at all. Tests hand in a transport.
module HomeAssistant
  class Error < StandardError; end
  # What a hub call can fail with: callers that must not raise rescue these.
  FAILURES = [ Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH ].freeze

  class << self
    attr_writer :url, :token, :webhook_secret
    # A lambda taking { method:, url:, path:, headers:, body: } and answering [status, json].
    attr_accessor :transport

    def url
      @url ||= setting(:url)&.chomp("/")
    end

    def token
      @token ||= setting(:token)
    end

    # The shared secret Home Assistant's automations send with alerts (plan: milestone 6):
    # home_assistant.webhook_secret in the credentials or HOME_ASSISTANT_WEBHOOK_SECRET.
    def webhook_secret
      @webhook_secret ||= setting(:webhook_secret)
    end

    def configured?
      url.present? && token.present?
    end

    def configure(url:, token:)
      @url, @token = url.chomp("/"), token
    end

    def reset!
      @url = @token = @transport = @webhook_secret = nil
    end

    # GET /api/camera_proxy/<entity>: [bytes, content type], nil when off.
    def camera_image(entity_id)
      return nil unless configured?
      headers = { "Authorization" => "Bearer #{token}" }
      path = "/api/camera_proxy/#{entity_id}"
      status, body, type = (transport || method(:http)).call(method: "GET", url: url + path, path: path, headers: headers, body: nil, binary: true)
      raise Error, "Home Assistant answered #{status} for the camera image" unless status.to_i.between?(200, 299)
      [ body, type.presence || "image/jpeg" ]
    end

    # GET /api/states/<entity>: { "state" => ..., "attributes" => {...} }, nil when off.
    def state(entity_id)
      request("GET", "/api/states/#{entity_id}")
    end

    # GET /api/states: every entity, nil when off.
    def states
      request("GET", "/api/states")
    end

    # GET /api/config: the hub's unit system among other things, nil when off.
    def config
      request("GET", "/api/config")
    end

    # "°C" or "°F" as the hub reports temperatures, "°C" when it does not say.
    def temperature_unit
      config&.dig("unit_system", "temperature").presence || "°C"
    rescue *FAILURES
      "°C"
    end

    # [[label, entity_id], ...] for the given domains ("light", "lock"...), for the settings pickers.
    def entities(domains)
      Array(states).filter_map do |s|
        id = s["entity_id"].to_s
        next unless domains.include?(id.split(".").first)
        [ "#{s.dig('attributes', 'friendly_name').presence || id} (#{id})", id ]
      end.sort_by(&:first)
    rescue Error, SocketError, Timeout::Error, Errno::ECONNREFUSED
      []
    end

    # POST /api/services/<domain>/<service>?return_response with the data; the JSON answer
    # ({ "service_response" => ... }), nil when off.
    def call(domain, service, data = {})
      request("POST", "/api/services/#{domain}/#{service}?return_response", data)
    end

    private

    def setting(name)
      Rails.application.credentials.dig(:home_assistant, name).presence || ENV["HOME_ASSISTANT_#{name.to_s.upcase}"].presence
    end

    def request(method, path, body = nil)
      return nil unless configured?
      headers = { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json", "Accept" => "application/json" }
      body = body&.deep_stringify_keys
      status, json = (transport || method(:http)).call(method: method, url: url + path, path: path.sub(/\?.*/, ""), headers: headers, body: body)
      raise Error, "Home Assistant answered #{status}: #{json.is_a?(Hash) ? json['message'] : json}" unless status.to_i.between?(200, 299)
      json
    end

    def http(request)
      uri = URI(request[:url])
      req = request[:method] == "POST" ? Net::HTTP::Post.new(uri, request[:headers]) : Net::HTTP::Get.new(uri, request[:headers])
      req.body = request[:body].to_json if request[:body]
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) { |h| h.request(req) }
      return [ response.code.to_i, response.body, response["Content-Type"] ] if request[:binary]
      [ response.code.to_i, (JSON.parse(response.body) rescue response.body) ]
    end
  end
end
