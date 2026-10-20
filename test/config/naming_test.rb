require "test_helper"

# The app was called home_dashboard before it was Home HQ; no file keeps the old name
# (service, volume, settings, module, cookie), so nothing half-renamed is left behind.
class NamingTest < ActiveSupport::TestCase
  test "no tracked file uses the old name" do
    files = `git -C #{Rails.root} ls-files -z`.split("\0") - [ "test/config/naming_test.rb" ]
    stale = files.select { |file| File.file?(Rails.root.join(file)) && File.read(Rails.root.join(file), mode: "rb").match?(/home[_-]?dashboard/i) }

    assert_empty stale
  end
end
