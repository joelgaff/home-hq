# Live sync (Pieces): after a broadcast names the pieces a write changed, each screen asks for
# the ones it shows, with its own context (the chores routine it is on, the shopping store and
# drawer), and gets them as Turbo Stream replaces rendered for itself.
class PiecesController < ApplicationController
  def show
    @household = Current.household
    ids = Array(params[:ids]).map(&:to_s).uniq & Pieces::REGISTRY.keys
    @pieces = ids.map { |id| [ id, Pieces::REGISTRY[id], locals_for(id) ] }
    render formats: :turbo_stream
  end

  private

  def locals_for(id)
    case id
    when "chores" then { routine: @household.routines.find_by(id: params[:routine]) || @household.current_routine }
    when "calendar" then CalendarController.locals_from(params, @household)
    when "people" then { person: @household.people.find_by(id: params[:person]) }
    when "shopping" then { store: @household.stores.find_by(id: params[:store]), drawer: params[:drawer].present? && params[:drawer] != "0", flash_id: nil }
    else {}
    end
  end
end
