# A line on the shared shopping list. Open → checked ("Got it" drawer) → cleared (gone, but
# restorable for the clear's Undo).
class GroceryItem < ApplicationRecord
  include SyncsPieces

  belongs_to :household
  syncs_pieces :shopping, :"shopping-side", :"today-shopping"
  belongs_to :category, optional: true
  belongs_to :store, optional: true

  validates :name, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }

  scope :live, -> { where(cleared_at: nil) }
  scope :open, -> { live.where(checked_at: nil) }
  scope :checked, -> { live.where.not(checked_at: nil) }
  scope :named, ->(name) { where("LOWER(name) = ?", name.downcase) }
  scope :in_order, -> { order(:created_at, :id) }

  def checked? = checked_at.present?
  def cleared? = cleared_at.present?

  def check!
    update!(checked_at: Current.now)
  end

  def uncheck!
    update!(checked_at: nil)
  end

  def revive!
    update!(checked_at: nil, quantity: 1)
  end

  def adjust_quantity!(delta)
    update!(quantity: [ 1, quantity + delta ].max)
  end

  def category_name
    category&.name || "Other"
  end
end
