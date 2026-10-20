# A shop with its own aisle order (store_categories). The first store is the default for new items.
class Store < ApplicationRecord
  include Audited
  include Positioned
  include SyncsPieces

  belongs_to :household
  has_many :store_categories, -> { order(:position) }, dependent: :destroy
  has_many :categories, through: :store_categories
  has_many :grocery_items, dependent: :nullify

  validates :name, presence: true
  audited "store"
  before_validation { place_last(household.stores) if household }
  syncs_pieces :shopping, :"shopping-side"

  scope :in_order, -> { order(:position, :id) }

  # Categories in this store's aisle order, falling back to the household's order for any it
  # has not placed.
  def aisle_order
    placed = categories.to_a
    placed + (household.categories.in_order - placed)
  end

  # Moves a category up or down this store's aisle order, writing the whole order down first
  # when the store had none of its own yet.
  def move_aisle!(category, direction)
    transaction do
      aisle_order.each_with_index do |c, i|
        store_categories.find_or_initialize_by(category: c).update!(position: i + 1)
      end
      store_categories.reload.find_by!(category: category).move!(direction, store_categories.order(:position))
    end
  end
end
