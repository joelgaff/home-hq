# The stars ledger: +N for a chore, opening balances and adjustments as free entries. A kid's
# total is the sum, so Undo never has to "subtract" (plan: Persistence).
class StarEntry < ApplicationRecord
  belongs_to :person
  belongs_to :todo, optional: true
  belongs_to :chore_completion, optional: true

  validates :amount, presence: true
end
