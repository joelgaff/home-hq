# A photo in the slideshow (ui-spec §1.5): an Immich asset (its image comes through us, plan:
# milestone 7) or a demo photo with a placeholder image keyed by `image_key`; captions are derived
# from the date and place.
class Photo < ApplicationRecord
  belongs_to :household
  belongs_to :person, optional: true

  validates :image_key, :taken_on, presence: true
  validates :orientation, inclusion: %w[landscape portrait]

  scope :in_order, -> { order(:taken_on, :id) }

  def portrait? = orientation == "portrait"

  def immich? = immich_id.present?

  def url(size = :large)
    if immich?
      routes = Rails.application.routes.url_helpers
      size == :small ? routes.image_photo_path(self, size: "small") : routes.image_photo_path(self)
    else
      w, h = portrait? ? [ 800, 1200 ] : [ 1600, 1000 ]
      w, h = w / 2, h / 2 if size == :small
      "https://picsum.photos/seed/#{image_key}/#{w}/#{h}"
    end
  end

  def on_this_day?(today = Current.now.to_date)
    taken_on.month == today.month && taken_on.day == today.day
  end

  # "5 years ago today" / "3 years ago" / "This year"
  def kicker(today = Current.now.to_date)
    years = today.year - taken_on.year
    return "#{years} #{'year'.pluralize(years)} ago today" if on_this_day?(today)
    years.positive? ? "#{years} #{'year'.pluralize(years)} ago" : "This year"
  end

  def date_label
    taken_on.strftime("%B %-d, %Y")
  end

  def month_year
    taken_on.strftime("%B %Y")
  end

  def as_slide
    { id: id, url: url, small: url(:small), portrait: portrait?, album: album, place: place, favorite: favorite?,
      on_this_day: on_this_day?, kicker: kicker, date: date_label, month_year: month_year }
  end
end
