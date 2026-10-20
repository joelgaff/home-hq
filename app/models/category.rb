# A shopping category (Produce, Bakery...). Position is the "All stores" order; items with no
# category show under "Other", last.
class Category < ApplicationRecord
  include Positioned
  include SyncsPieces

  belongs_to :household
  has_many :store_categories, dependent: :destroy
  has_many :catalog_items, dependent: :nullify
  has_many :grocery_items, dependent: :nullify

  validates :name, presence: true
  before_validation { place_last(household.categories) if household }
  syncs_pieces :shopping, :"shopping-side"

  scope :in_order, -> { order(:position, :id) }
end
