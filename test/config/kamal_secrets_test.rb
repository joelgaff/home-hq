require "test_helper"
require "open3"
require "tmpdir"

# Deploy secrets follow Kamal's own convention: `.kamal/secrets` is committed and holds only
# `$VARIABLE` references; the values live in a gitignored `.env` that `bin/kamal` loads, filled
# from 1Password once per machine by `bin/secrets-pull`. No password manager runs at deploy time.
class KamalSecretsTest < ActiveSupport::TestCase
  SECRETS_FILE = Rails.root.join(".kamal/secrets")
  REQUIRED = %w[RAILS_MASTER_KEY TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID LITESTREAM_ACCESS_KEY_ID
                LITESTREAM_SECRET_ACCESS_KEY LITESTREAM_BUCKET LITESTREAM_ENDPOINT].freeze

  test "the committed secrets file only references variables, never a password manager" do
    source = File.read(SECRETS_FILE)
    code = source.lines.grep_v(/^\s*#/).join
    assert_no_match(/\bop\b|1password|secrets fetch|secrets extract|\$\(/i, code)
    REQUIRED.each do |name|
      assert_match(/^#{name}=\$#{name}$/, source, "#{name} must be a plain $#{name} reference")
    end
  end

  test ".env is ignored by git" do
    assert_match(%r{^/\.env\*$}, File.read(Rails.root.join(".gitignore")))
  end

  test "bin/kamal loads the values from the env file" do
    Dir.mktmpdir do |dir|
      env_file = File.join(dir, "env")
      File.write(env_file, REQUIRED.map { |name| "#{name}=value-of-#{name.downcase}" }.join("\n") + "\n")
      out, err, status = Open3.capture3(
        { "HOME_HQ_ENV_FILE" => env_file, "KAMAL_SKIP_HOOKS" => "1",
          "HOME_HQ_SERVER" => "203.0.113.10", "HOME_HQ_DOMAIN" => "dash.example.net" },
        "bin/kamal", "secrets", "print", chdir: Rails.root.to_s)
      assert status.success?, err
      assert_includes out, "RAILS_MASTER_KEY=value-of-rails_master_key"
      assert_includes out, "LITESTREAM_ENDPOINT=value-of-litestream_endpoint"
    end
  end

  test "bin/secrets-pull writes .env from the 1Password item with one op call, mode 600" do
    Dir.mktmpdir do |dir|
      fake_bin = File.join(dir, "bin")
      Dir.mkdir(fake_bin)
      File.write(File.join(fake_bin, "op"), <<~SH)
        #!/bin/sh
        echo "$@" >> "#{dir}/op-calls"
        cat <<'JSON'
        {"fields":[
          {"id":"a","label":"master_key","value":"mk-123"},
          {"id":"b","label":"r2_access_key_id","value":"r2id"},
          {"id":"c","label":"r2_secret_access_key","value":"r2secret"},
          {"id":"d","label":"r2_bucket","value":"home-hq"},
          {"id":"e","label":"r2_endpoint","value":"https://x.r2.cloudflarestorage.com"},
          {"id":"f","label":"telegram_bot_token","value":"123:abc"},
          {"id":"g","label":"telegram_chat_id","value":"42"},
          {"id":"h","label":"notesPlain","value":"ignored"}
        ]}
        JSON
      SH
      File.chmod(0o755, File.join(fake_bin, "op"))
      env_file = File.join(dir, ".env")

      out, err, status = Open3.capture3(
        { "PATH" => "#{fake_bin}:#{ENV["PATH"]}", "HOME_HQ_ENV_FILE" => env_file },
        "bin/secrets-pull", chdir: Rails.root.to_s)

      assert status.success?, out + err
      assert_equal 1, File.readlines(File.join(dir, "op-calls")).size, "one op call"
      assert_equal "600", File.stat(env_file).mode.to_s(8)[-3..]
      written = File.read(env_file)
      assert_includes written, "RAILS_MASTER_KEY=mk-123\n"
      assert_includes written, "LITESTREAM_ENDPOINT=https://x.r2.cloudflarestorage.com\n"
      assert_includes written, "TELEGRAM_BOT_TOKEN=123:abc\n"
      assert_includes written, "TELEGRAM_CHAT_ID=42\n"
      assert_no_match(/ignored|notesPlain/, written)
      assert_no_match(/mk-123|r2secret/, out + err, "values never echoed")
    end
  end
end
