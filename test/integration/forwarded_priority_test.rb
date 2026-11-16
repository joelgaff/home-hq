require "test_helper"

# GHSA-2gff-2mmg-m73p and GHSA-qfgr-crr9-7r49: these tests call Rack directly,
# without Rails computing request.remote_ip first, so they only pass if Rack
# itself ignores a client-supplied Forwarded header.
class ForwardedPriorityTest < ActiveSupport::TestCase
  PROXY_ADDR = "172.18.0.2"
  CLIENT_IP = "203.0.113.7"
  SPOOFED_IP = "198.51.100.66"

  test "Rack resolves the client address from X-Forwarded-For only" do
    assert_equal [ :x_forwarded ], Rack::Request.forwarded_priority
    assert_equal CLIENT_IP, Rack::Request.new(spoofed_env).ip
  end

  test "Rack ignores a host and scheme smuggled through Forwarded" do
    request = Rack::Request.new(spoofed_env)

    assert_equal "example.org", request.host
    assert_equal "http", request.scheme
  end

  private
    def spoofed_env
      Rack::MockRequest.env_for("http://example.org/",
        "REMOTE_ADDR" => PROXY_ADDR,
        "HTTP_X_FORWARDED_FOR" => CLIENT_IP,
        "HTTP_FORWARDED" => "for=#{SPOOFED_IP};host=evil.example;proto=https")
    end
end
