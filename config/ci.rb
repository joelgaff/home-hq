# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  # The wall frame runs Android System WebView 106: reject CSS/JS it cannot run (docs/ui-spec.md §6).
  step "Compatibility: WebView 106 assets", "bin/webview-check app/assets/stylesheets app/javascript"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  # Scan the encrypted credentials as stored, not decrypted through the rails_credentials
  # textconv driver (which would both boot Rails and feed real secrets to the scanner).
  step "Security: Secret scan", "env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.rails_credentials.textconv GIT_CONFIG_VALUE_0=cat gitleaks git --no-banner --redact --exit-code 1"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Stimulus behaviours from docs/ui-spec.md, in a headless Chromium sized like the frame.
  # Two browser workers: the machine also hosts production, and more workers only add timing flakes.
  step "Tests: System", "env PARALLEL_WORKERS=2 bin/rails test:system"

  # Signoff (the green GitHub status) happens in .githooks/pre-push, once the
  # commit is on GitHub.
end
