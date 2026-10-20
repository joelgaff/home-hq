require "test_helper"
require "erb"
require "yaml"

# The deploy config (plan: Hosting, 2026-10-16): one file for a VPS with its own TLS or a machine
# at home behind a Cloudflare Tunnel, chosen by environment variables so nothing machine-specific
# is committed.
class DeployConfigTest < ActiveSupport::TestCase
  KEYS = %w[HOME_DASHBOARD_SERVER HOME_DASHBOARD_DOMAIN HOME_DASHBOARD_SSH_USER HOME_DASHBOARD_TLS CLOUDFLARE_TUNNEL_TOKEN].freeze

  def render(env)
    saved = KEYS.to_h { |k| [ k, ENV[k] ] }
    KEYS.each { |k| ENV.delete(k) }
    env.each { |k, v| ENV[k] = v }
    YAML.safe_load(ERB.new(File.read(Rails.root.join("config/deploy.yml"))).result, aliases: true)
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "a VPS: root over SSH, the proxy terminates TLS, no tunnel" do
    config = render("HOME_DASHBOARD_SERVER" => "203.0.113.10", "HOME_DASHBOARD_DOMAIN" => "dash.example.net")
    assert_equal true, config["proxy"]["ssl"]
    assert_equal "dash.example.net", config["proxy"]["host"]
    assert_equal "root", config.dig("ssh", "user")
    assert_nil config["accessories"]["tunnel"]
    assert_equal [ "203.0.113.10" ], config["servers"]["web"]
    assert_equal [ "203.0.113.10" ], config["servers"]["bridge"]["hosts"]
    assert_equal "localhost:5555", config["registry"]["server"]
  end

  test "at home: a user over SSH, plain HTTP behind the Cloudflare Tunnel accessory on the host network" do
    config = render("HOME_DASHBOARD_SERVER" => "127.0.0.1", "HOME_DASHBOARD_DOMAIN" => "dash.example.net",
      "HOME_DASHBOARD_SSH_USER" => "deploy", "HOME_DASHBOARD_TLS" => "false", "CLOUDFLARE_TUNNEL_TOKEN" => "t")
    assert_equal false, config["proxy"]["ssl"]
    assert_equal "deploy", config.dig("ssh", "user")
    tunnel = config["accessories"]["tunnel"]
    assert_match(/cloudflared/, tunnel["image"])
    assert_nil tunnel["options"], "on the kamal network, where kamal-proxy is reachable by name"
    assert_includes tunnel.dig("env", "secret"), "TUNNEL_TOKEN"
    assert_match(/tunnel .*run/, tunnel["cmd"])
    assert_equal "127.0.0.1", tunnel["host"]
    assert_equal "127.0.0.1:5555", config["registry"]["server"], "no SSH port forward when the server is this machine"
    assert_equal "local", config["registry"]["username"]
  end

  test "the secrets file passes the tunnel token through" do
    assert_match(/^TUNNEL_TOKEN=\$CLOUDFLARE_TUNNEL_TOKEN$/, File.read(Rails.root.join(".kamal/secrets")))
  end

  HUB = %w[HOME_ASSISTANT_URL HOME_ASSISTANT_TOKEN HOME_ASSISTANT_WEBHOOK_SECRET IMMICH_URL IMMICH_API_KEY].freeze

  test "the home hub and photo library settings reach the app from the secrets (empty = off)" do
    config = render("HOME_DASHBOARD_SERVER" => "127.0.0.1")
    assert_empty HUB - config.dig("env", "secret"), "every hub setting is an app secret"
    secrets = File.read(Rails.root.join(".kamal/secrets"))
    HUB.each { |name| assert_match(/^#{name}=\$#{name}$/, secrets) }
    pull = File.read(Rails.root.join("bin/secrets-pull"))
    HUB.each { |name| assert_includes pull, %("#{name}"), "secrets-pull fills #{name}" }
  end
end
