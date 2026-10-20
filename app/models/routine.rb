# A time-of-day block of chores: Morning, After school, Evening (ui-spec §1.3). Hours are
# [from_hour, to_hour) on a 24-hour clock; the last routine also catches the small hours.
class Routine < ApplicationRecord
  include Audited
  include Scheduled
  include Positioned
  include SyncsPieces

  belongs_to :household
  has_many :chores, dependent: :destroy

  validates :name, :from_hour, :to_hour, presence: true
  audited "routine"
  validates :from_hour, :to_hour, numericality: { only_integer: true, in: 0..24 }
  before_validation { place_last(household.routines) if household }
  before_validation :default_range_label
  syncs_pieces :chores, :"today-chores"

  scope :in_order, -> { order(:position, :id) }

  def covers?(hour)
    hour >= from_hour && hour < to_hour
  end

  # A weekend-only routine is not active on a Wednesday (plan: Simplifications).
  def active_on?(date)
    on_weekday?(date)
  end

  # Over for the day once its last hour has passed.
  def over_at?(time)
    time.hour >= to_hour
  end

  # "8 AM – 12 PM" from the hours, unless the label is written by hand.
  def default_range_label
    self.range_label = "#{hour_word(from_hour)} – #{hour_word(to_hour)}" if range_label.blank? && from_hour && to_hour
  end

  def hour_word(h)
    h = h.to_i % 24
    "#{h % 12 == 0 ? 12 : h % 12} #{h < 12 ? 'AM' : 'PM'}"
  end

  # "Nothing this morning / afternoon / evening"
  def part_of_day
    return "morning" if from_hour < 11
    return "evening" if from_hour >= 17
    "afternoon"
  end
end
