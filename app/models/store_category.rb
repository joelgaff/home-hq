# Where a category sits in one store's aisle order.
class StoreCategory < ApplicationRecord
  include Positioned

  belongs_to :store
  belongs_to :category
end
