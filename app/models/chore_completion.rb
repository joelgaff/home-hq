# One chore done on one day, by someone when it matters (Anyone chores). Deleting it is the Undo:
# the star entries it earned go with it.
class ChoreCompletion < ApplicationRecord
  include SyncsPieces

  belongs_to :chore
  syncs_pieces :chores, :"today-chores", household: -> { chore.household }
  belongs_to :person, optional: true
  has_many :star_entries, dependent: :destroy

  validates :completed_on, presence: true
  after_commit { Current.chores_cache = nil }

  def undo!
    AuditEntry.record("chore.undone", household: chore.household, subject: chore)
    destroy!
    chore.completions_today.reset
  end
end
