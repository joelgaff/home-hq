class ApplicationController < ActionController::Base
  include Authentication

  before_action :set_household
  around_action :batch_piece_broadcasts
  helper_method :frame_layout?
  around_action :use_household_time_zone
  before_action :set_clock_offset

  private

  # SINGLE-TENANT today: the one tenant. (.sole raises if a 2nd appears — a useful guard.)
  # MULTI-TENANT later: resolve by subdomain/session, e.g.
  #   Household.find_by!(subdomain: request.subdomain)
  def set_household
    Current.household = Household.first
  end

  # Who is signed in picks the layout (plan: Small screens): an enrolled screen is the wall frame
  # (fixed 1280×800 stage); a person gets the device-width app with the phone layer under 700 px.
  def frame_layout?
    current_screen.present?
  end

  # Live sync: one "pieces" broadcast per request, tagged with the writing page's token
  # (dashboard/sync.js) so that page skips it.
  def batch_piece_broadcasts(&block)
    Current.page_token = request.headers["X-Page-Token"].presence
    Pieces.batch(origin: Current.page_token, &block)
  end

  def use_household_time_zone(&block)
    Time.use_zone(Current.household&.time_zone || Time.zone, &block)
  end

  # The demo drawer's time presets shift "now" for this browser only (docs/ui-spec.md §0).
  def set_clock_offset
    Current.clock_offset = session[:clock_offset].to_f.seconds if session[:clock_offset]
    Current.calendar_mode = session[:calendar_mode]
  end
end
