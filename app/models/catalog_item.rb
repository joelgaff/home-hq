# Something the household buys: gives new list items their proper name and category, feeds the
# suggestions while typing, and (when usual) the tap-to-add tiles (ui-spec §1.4).
class CatalogItem < ApplicationRecord
  include Positioned
  include SyncsPieces

  belongs_to :household
  belongs_to :category, optional: true

  validates :name, presence: true
  before_validation { place_last(household.catalog_items) if household }
  syncs_pieces :shopping, :"shopping-side"

  scope :in_order, -> { order(:position, :id) }
  scope :usual, -> { where(usual: true) }
end
