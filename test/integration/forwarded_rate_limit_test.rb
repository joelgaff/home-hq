require "test_helper"

# GHSA-2gff-2mmg-m73p: behind the proxy a client could add its own `Forwarded` header, which
# outranked the proxy's X-Forwarded-For, and so pick the address the sign-in rate limit counts.
class ForwardedRateLimitTest < ActionDispatch::IntegrationTest
  test "rotating a spoofed Forwarded header does not get around the sign-in rate limit" do
    served = 0
    15.times do |n|
      post session_path,
           params: { email: "owner@example.com" },
           headers: { "X-Forwarded-For" => "203.0.113.9", "Forwarded" => "for=198.51.100.#{n + 1}" }
      served += 1 unless flash[:alert].to_s.match?(/too many/i)
    rescue ActionDispatch::RemoteIp::IpSpoofAttackError
      # The conflicting headers are refused outright, which is as good as a limit.
    end
    assert_operator served, :<=, 10
  end
end
