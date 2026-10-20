# Event sheets (ui-spec §1.2): one event, or the list behind a "+N more" block.
class EventsController < ApplicationController
  before_action { @household = Current.household }

  def index
    ids = params[:ids].to_s.split(",").map(&:to_i)
    @events = Current.household.events.where(id: ids).includes(attendees: :person).by_start
    render partial: "events/more", layout: false
  end

  def show
    @event = Current.household.events.includes(attendees: :person).find(params[:id])
    render partial: "events/sheet", layout: false
  end

  # "Send directions to phone" v1: a QR code of a maps link for the location, scanned with a
  # phone camera (plan: second gap review). Apple Maps links open Google Maps elsewhere.
  def directions
    @event = Current.household.events.find(params[:id])
    return head :not_found if @event.location.blank?
    @maps_url = "https://maps.apple.com/?daddr=#{CGI.escape(@event.location)}"
    @qr_svg = RQRCode::QRCode.new(@maps_url).as_svg(module_size: 5, standalone: true, use_path: true, color: "111111", viewbox: true).html_safe
    render partial: "events/directions", layout: false
  end

  # "Who is it for" from the sheet (plan: Calendars, rule 1): a new set of people, or back to
  # what the calendar says. Answers with the sheet and a nudge to refetch the calendar pieces.
  def update
    @event = Current.household.events.find(params[:id])
    if params[:reset].present?
      @event.clear_people_override!
    elsif params[:everyone].present?
      @event.override_people!(Current.household.people.to_a)
    else
      ids = Array(params[:person_ids]).flat_map { |v| v.to_s.split(",") }.map(&:to_i)
      people = Current.household.people.where(id: ids).to_a.presence || Current.household.people.to_a
      @event.override_people!(people)
    end
    @event.reload
    render :update, formats: :turbo_stream
  end
end
