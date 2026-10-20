# Who an event is for. All of the household's people → a family event (ui-spec §1.2).
class Attendee < ApplicationRecord
  include SyncsPieces

  belongs_to :event
  belongs_to :person

  syncs_pieces :"today-hero", :"today-lanes", :"today-agenda", :calendar, household: -> { event&.household }
end
