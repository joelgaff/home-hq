require "net/http"

# The Immich client (plan: Integrations: photos): the photo library on the home server. Configured
# by `immich.url` / `immich.api_key` in the credentials or IMMICH_URL / IMMICH_API_KEY; off (every
# call answers nil) until then. Tests hand in a transport answering [status, json or bytes, type].
module Immich
  class Error < StandardError; end
  FAILURES = [ Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH ].freeze

  class << self
    attr_writer :url, :api_key
    attr_accessor :transport

    def url
      @url ||= setting(:url)&.chomp("/")
    end

    def api_key
      @api_key ||= setting(:api_key)
    end

    def configured?
      url.present? && api_key.present?
    end

    def configure(url:, api_key:)
      @url, @api_key = url.chomp("/"), api_key
    end

    def reset!
      @url = @api_key = @transport = nil
    end

    def albums = get("/api/albums")
    def album(id) = get("/api/albums/#{id}")
    def search(body) = post("/api/search/metadata", body)

    def favorite!(ids, favorite)
      put("/api/assets", { ids: Array(ids), isFavorite: favorite })
    end

    # [bytes, content type] for an asset's preview or thumbnail; nil when off.
    def thumbnail(asset_id, size: "preview")
      return nil unless configured?
      path = "/api/assets/#{asset_id}/thumbnail"
      status, body, type = (transport || method(:http)).call(method: "GET", url: "#{url}#{path}?size=#{size}", path: path, headers: headers, body: nil, binary: true)
      raise Error, "Immich answered #{status} for the image" unless status.to_i.between?(200, 299)
      [ body, type.presence || "image/jpeg" ]
    end

    def get(path, params = {})
      query = params.any? ? "?#{params.to_query}" : ""
      request("GET", path, query: query)
    end

    def post(path, body) = request("POST", path, body: body)
    def put(path, body) = request("PUT", path, body: body)

    private

    def setting(name)
      Rails.application.credentials.dig(:immich, name).presence || ENV["IMMICH_#{name.to_s.upcase}"].presence
    end

    def headers
      { "x-api-key" => api_key, "Accept" => "application/json", "Content-Type" => "application/json" }
    end

    def request(method, path, body: nil, query: "")
      return nil unless configured?
      body = body&.deep_stringify_keys
      status, json = (transport || method(:http)).call(method: method, url: "#{url}#{path}#{query}", path: path, headers: headers, body: body)
      raise Error, "Immich answered #{status}: #{json.is_a?(Hash) ? json['message'] : json}" unless status.to_i.between?(200, 299)
      json
    end

    def http(request)
      uri = URI(request[:url])
      klass = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post, "PUT" => Net::HTTP::Put }.fetch(request[:method])
      req = klass.new(uri, request[:headers])
      req.body = request[:body].to_json if request[:body]
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) { |h| h.request(req) }
      return [ response.code.to_i, response.body, response["Content-Type"] ] if request[:binary]
      [ response.code.to_i, (JSON.parse(response.body) rescue response.body) ]
    end
  end
end
