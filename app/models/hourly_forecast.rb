class HourlyForecast < ApplicationRecord
  belongs_to :weather_report

  validates :hour, inclusion: 0..23
  validates :temperature, :condition, presence: true
end
