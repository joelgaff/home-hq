require "net/http"

# Open-Meteo (owner, 2026-10-19): free weather with no key, for a household without Home
# Assistant's weather. `geocode` turns a typed place into coordinates; `forecast` reads today's
# hourly and daily forecast in the household's unit and zone. Tests hand in a transport answering
# [status, json] for a URL.
module OpenMeteo
  class Error < StandardError; end
  FAILURES = [ Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, JSON::ParserError ].freeze
  GEOCODER = "https://geocoding-api.open-meteo.com/v1/search"
  FORECAST = "https://api.open-meteo.com/v1/forecast"

  Place = Data.define(:label, :latitude, :longitude)

  class << self
    attr_accessor :transport

    def reset! = self.transport = nil

    # The best match for a place name, or nil.
    def geocode(name)
      result = get(GEOCODER, name: name.to_s.strip, count: 1, language: "en", format: "json")["results"]&.first
      return nil unless result
      label = [ result["name"], result["admin1"], result["country_code"] ].compact_blank.uniq.join(", ")
      Place.new(label: label, latitude: result["latitude"], longitude: result["longitude"])
    end

    def forecast(latitude:, longitude:, unit:, zone:)
      get(FORECAST, latitude: latitude, longitude: longitude, hourly: "temperature_2m,weather_code,precipitation_probability,is_day",
                    daily: "temperature_2m_max,temperature_2m_min", temperature_unit: unit == "f" ? "fahrenheit" : "celsius",
                    timezone: zone, forecast_days: 1)
    end

    private

    def get(base, params)
      url = "#{base}?#{params.to_a.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
      status, body = (transport || method(:http)).call(url)
      raise Error, "Open-Meteo answered #{status}" unless status.to_i.between?(200, 299)
      body || {}
    end

    def http(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |h| h.get(uri.request_uri) }
      [ response.code.to_i, JSON.parse(response.body) ]
    end
  end
end
