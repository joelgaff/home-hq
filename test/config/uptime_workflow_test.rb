require "test_helper"
require "yaml"

# The outside uptime check: a scheduled GitHub workflow, off the home
# network, asks the public /up and tells the Telegram chat when the app goes down and when it is
# back. The address and the bot are repository secrets, so nothing household-specific is committed.
class UptimeWorkflowTest < ActiveSupport::TestCase
  PATH = Rails.root.join(".github/workflows/uptime.yml")

  test "runs on a schedule and by hand, reading the address and the bot from secrets" do
    workflow = YAML.safe_load(File.read(PATH), aliases: true)
    triggers = workflow["on"] || workflow[true]
    assert triggers["schedule"].first["cron"].present?
    assert triggers.key?("workflow_dispatch")
    text = File.read(PATH)
    %w[HOME_HQ_URL TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID].each { |name| assert_includes text, "secrets.#{name}" }
    assert_no_match(/https?:\/\/(?!api\.telegram\.org)[a-z0-9.-]+\.[a-z]{2,}/i, text.gsub(/^\s*#.*$/, ""), "no address is committed")
  end

  test "alerts on a change of state only, remembered between runs" do
    text = File.read(PATH)
    assert_includes text, "actions/cache/restore"
    assert_includes text, "actions/cache/save"
    assert_match(/is down/, text)
    assert_match(/is back/, text)
  end

  test "a failed probe prints no error, which would name the host in the public log" do
    probe = File.read(PATH).lines.find { |l| l.include?('"$URL/up"') }
    assert_match(/curl -fs /, probe)
  end
end
