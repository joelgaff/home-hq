# The slideshow's pool (ui-spec §1.5): every photo once, favourites twice, on-this-day photos
# first; the browser shuffles the rest and picks layouts.
module Household::Photos
  extend ActiveSupport::Concern

  included do
    has_many :photos, -> { in_order }, dependent: :destroy
  end

  def slideshow_pool
    pool = photos.includes(:person).flat_map { |p| p.favorite? ? [ p, p ] : [ p ] }
    pool.sort_by { |p| p.on_this_day? ? 0 : 1 }
  end
end
