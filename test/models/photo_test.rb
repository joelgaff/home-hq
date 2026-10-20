require "test_helper"

# Photo captions from docs/ui-spec.md §1.5, and the slideshow's "favourites twice, on-this-day
# first" queue.
class PhotoTest < ActiveSupport::TestCase
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  test "on this day, N years ago today" do
    assert photos(:tofino).on_this_day?
    assert_equal "5 years ago today", photos(:tofino).kicker
    assert_not photos(:cottage).on_this_day?
    assert_equal "3 years ago", photos(:cottage).kicker
    assert_equal "This year", photos(:pancakes).kicker
    assert_equal "October 14, 2021", photos(:tofino).date_label
    assert_equal "October 2021", photos(:tofino).month_year
  end

  test "portrait photos know it" do
    assert photos(:kite_a).portrait?
    assert_not photos(:tofino).portrait?
  end

  test "image urls come in two sizes per orientation" do
    assert_equal "https://picsum.photos/seed/tofino-surf/1600/1000", photos(:tofino).url
    assert_equal "https://picsum.photos/seed/tofino-surf/800/500", photos(:tofino).url(:small)
    assert_equal "https://picsum.photos/seed/maya-kite/800/1200", photos(:kite_a).url
  end

  test "the slideshow pool lists favourites twice with on-this-day photos first" do
    pool = households(:primary).slideshow_pool
    assert_equal "tofino-surf", pool.first.image_key
    assert_equal 2, pool.count { |p| p.image_key == "cottage-dock" }
    assert_equal 6, pool.size
  end
end
