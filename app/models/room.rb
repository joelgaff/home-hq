class Room < ApplicationRecord
  include Positioned

  belongs_to :household
  has_many :devices, -> { in_order }, dependent: :nullify

  validates :name, presence: true
  before_validation { place_last(household.rooms) if household }

  scope :in_order, -> { order(:position, :id) }

  # "2 on" / "All off" for the room header (ui-spec §1.6).
  def lights_line
    on = devices.count { |d| d.light? && d.on? }
    on.positive? ? "#{on} on" : "All off"
  end
end
