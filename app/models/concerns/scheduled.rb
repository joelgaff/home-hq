# Weekday schedules for chores and routines (plan: Gap review answers): `weekdays` is a bitmask
# (mon = 1 ... sun = 64); nil means every day.
module Scheduled
  extend ActiveSupport::Concern

  DAYS = %w[mon tue wed thu fri sat sun].freeze

  class_methods do
    # Chore.weekdays_mask(%w[mon wed]) => 5
    def weekdays_mask(names)
      names = Array(names).map { |n| n.to_s.downcase[0, 3] }
      mask = DAYS.each_with_index.sum { |d, i| names.include?(d) ? 1 << i : 0 }
      mask.zero? ? nil : mask
    end
  end

  def every_day?
    weekdays.nil? || weekdays.zero?
  end

  # Forms post weekday names; [] (or nothing) means every day.
  def weekday_names=(names)
    self.weekdays = self.class.weekdays_mask(Array(names).reject(&:blank?))
  end

  # ["mon", "wed"], or [] for every day
  def weekday_names
    return [] if every_day?
    DAYS.each_with_index.filter_map { |d, i| d if weekdays[i] == 1 }
  end

  # Monday = 0 ... Sunday = 6, matching DAYS.
  def on_weekday?(date)
    every_day? || weekdays[(date.wday + 6) % 7] == 1
  end
end
