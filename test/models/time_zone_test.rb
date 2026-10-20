require "test_helper"

# The household's zone is stored as an IANA name (what Time.find_zone, the database and the deploy
# already use); Rails' own zone names are accepted on the way in and normalised.
class TimeZoneTest < ActiveSupport::TestCase
  test "a Rails zone name is stored as its IANA name" do
    h = households(:primary)
    h.time_zone = "Pacific Time (US & Canada)"
    assert_equal "America/Los_Angeles", h.time_zone
    h.time_zone = "America/Los_Angeles"
    assert_equal "America/Los_Angeles", h.time_zone
    h.time_zone = "UTC"
    assert_equal "Etc/UTC", h.time_zone
  end

  test "an unknown zone is refused" do
    h = households(:primary)
    h.time_zone = "Mars/Olympus_Mons"
    assert_not h.valid?
    assert_includes h.errors[:time_zone].join, "known"
  end

  test "the select options are IANA names, one per zone" do
    options = Household.time_zone_options
    assert_includes options, [ "(GMT-08:00) Pacific Time (US & Canada)", "America/Los_Angeles" ]
    assert_equal options.map(&:last).uniq.size, options.size
  end
end
