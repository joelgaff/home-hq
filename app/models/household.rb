# The tenant: one family, its people and everything on their wall. Each area of the dashboard
# has its own concern (Calendar, Chores, Shopping, HomeControl, Photos).
class Household < ApplicationRecord
  include SyncsPieces
  include Calendar
  include Chores
  include Shopping
  include HomeControl
  include Photos

  # Settings every page bakes in (its clock, its offset, its units): when they change the screens
  # reload rather than patch (Pieces only moves pieces).
  RELOAD_SETTINGS = %w[time_zone temperature_unit clock_format week_start].freeze

  has_many :audit_entries, dependent: :destroy
  has_many :home_alerts, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :screens, dependent: :destroy
  has_many :people, -> { in_order }, dependent: :destroy
  has_many :weather_reports, dependent: :destroy

  validates :name, presence: true
  validate { errors.add(:time_zone, "is not a known zone") unless ActiveSupport::TimeZone[time_zone.to_s] }
  validates :temperature_unit, inclusion: %w[c f]
  validates :clock_format, inclusion: %w[12 24]
  validates :week_start, inclusion: %w[monday sunday]
  # Waze regions (plan: Integrations, travel): the Americas, Europe, Israel, Australia.
  TRAVEL_REGIONS = { "us" => "Americas", "eu" => "Europe", "il" => "Israel", "au" => "Australia" }.freeze
  validates :travel_region, inclusion: TRAVEL_REGIONS.keys
  syncs_pieces :"control-scenes", household: -> { self }, if: -> { saved_change_to_active_scene_id? }
  syncs_pieces :chores, :"today-chores", household: -> { self }, if: -> { saved_change_to_chores_paused_until? }
  after_update_commit :reload_screens, if: -> { RELOAD_SETTINGS.any? { |name| saved_change_to_attribute?(name) } }
  after_save { Current.chores_cache = nil if saved_change_to_chores_paused_until? }
  validate :locate_weather, if: :will_save_change_to_weather_location?
  after_update { convert_stored_temperatures!(from: temperature_unit_before_last_save) if saved_change_to_temperature_unit? }
  # Settings changes go in the audit log (plan: milestone 5); scene and demo bookkeeping do not.
  after_update do
    changes = saved_changes.except("updated_at", "active_scene_id", "demo")
    AuditEntry.record("household.updated", household: self, subject: self, subject_name: name, details: { "changes" => changes }) if changes.any?
  end

  def family
    @family ||= Family.new(self)
  end

  # ---------------------------------------------------------------- time zone
  # Stored as an IANA name (America/Los_Angeles), which is what Time.find_zone, the database and
  # the deploy use; Rails' own names ("Pacific Time (US & Canada)") are normalised on the way in.
  def time_zone=(value)
    super(ActiveSupport::TimeZone[value.to_s]&.tzinfo&.name || value)
  end

  # [label, IANA name] for the settings select, one entry per zone.
  def self.time_zone_options
    ActiveSupport::TimeZone.all.map { |z| [ z.to_s, z.tzinfo.name ] }.uniq(&:last)
  end

  # ---------------------------------------------------------------- units and clock (plan: Our instance)
  def fahrenheit? = temperature_unit == "f"
  def clock_24? = clock_format == "24"

  def degrees
    fahrenheit? ? "°F" : "°C"
  end

  # Weather advice: "Clear and cool" below this (Wes's 12 °C ≈ 54 °F).
  def cool_below
    fahrenheit? ? 54 : 12
  end

  # A temperature read in another unit ("°C"/"°F"; blank = already ours), rounded to a degree.
  def convert_temperature(value, from:)
    return nil if value.nil?
    convert_exact(value, from: from).round
  end

  def convert_exact(value, from:)
    v = value.to_f
    case [ from.to_s.delete("°").downcase, temperature_unit ]
    in [ "c", "f" ] then v * 9 / 5 + 32
    in [ "f", "c" ] then (v - 32) * 5 / 9
    else v
    end
  end

  # A typed weather place becomes coordinates (and the geocoder's own label); blank clears it.
  def locate_weather
    if weather_location.blank?
      self.weather_location = self.weather_latitude = self.weather_longitude = nil
      return
    end
    place = OpenMeteo.geocode(weather_location)
    return errors.add(:weather_location, "couldn't find that place; try a city and region") unless place
    self.weather_location, self.weather_latitude, self.weather_longitude = place.label, place.latitude, place.longitude
  rescue *OpenMeteo::FAILURES
    errors.add(:weather_location, "couldn't be looked up just now; try again")
  end

  def weather_located? = weather_latitude.present? && weather_longitude.present?

  # Everything stored in the old unit, restated in ours: the thermostat and the weather reports.
  def convert_stored_temperatures!(from:)
    to_ours = ->(v) { v.nil? ? nil : convert_exact(v, from: from) }
    if thermostat
      thermostat.update_columns(%w[current_temperature target_temperature outside_temperature].to_h { |a| [ a, to_ours.(thermostat[a])&.round(1) ] })
    end
    weather_reports.includes(:hourly_forecasts).each do |report|
      report.update_columns(high: to_ours.(report.high).round, low: to_ours.(report.low).round)
      report.hourly_forecasts.each { |h| h.update_columns(temperature: to_ours.(h.temperature).round) }
    end
  end

  # Our temperature expressed in another unit ("°C"/"°F"), to one decimal, for the hub.
  def temperature_in(value, unit)
    v = value.to_f
    v = case [ temperature_unit, unit.to_s.delete("°").downcase ]
    in [ "f", "c" ] then (v - 32) * 5 / 9
    in [ "c", "f" ] then v * 9 / 5 + 32
    else v
    end
    v.round(1)
  end

  def thermostat_step
    fahrenheit? ? 1.0 : 0.5
  end

  def thermostat_range
    fahrenheit? ? (60.0..82.0) : (15.0..28.0)
  end

  # ---------------------------------------------------------------- the week (month view, chores strip)
  def week_start_day
    week_start.to_sym
  end

  def beginning_of_week(date)
    date.to_date.beginning_of_week(week_start_day)
  end

  # "Mon".."Sun" or "Sun".."Sat"
  def week_day_names
    %w[Mon Tue Wed Thu Fri Sat Sun].rotate(week_start_day == :sunday ? -1 : 0)
  end

  def week_day_letters
    week_day_names.map { |d| d[0] }
  end

  # From the demo data to the real household (plan: milestone 3 "start fresh"): everything bound to
  # the demo people goes (people, events, routines, chores, stars, stores, lists); the generic
  # catalogue comes back; logins and screens stay; home control, photos and weather stay demo
  # until their milestones; the demo tools (drawer, presets, tip) go. Then people, routines,
  # chores and stores are entered in Settings.
  def fresh_start!
    transaction do
      events.destroy_all
      chores.destroy_all
      routines.destroy_all
      people.destroy_all
      grocery_items.delete_all
      stores.destroy_all
      catalog_items.delete_all
      categories.destroy_all
      update!(active_scene: nil, chores_paused_until: nil, demo: false)
      seed_catalog!
      clear_samples!
    end
  end

  # What the demo left that the household's own sources replace: the sample home (rooms, devices,
  # scenes, cameras, thermostat, speaker), the sample photos (not from Immich) and the sample
  # weather (no source). People, chores, calendars, the shopping list and the catalogue stay.
  def clear_samples!
    transaction do
      clear_home!
      photos.where(immich_id: nil).destroy_all
      weather_reports.where(source: nil).destroy_all
    end
  end

  # ---------------------------------------------------------------- getting started
  # The setup steps in the order that works (plan: Settings): the only hard dependency is that a
  # chore lives in a routine; the rest is the sensible order. Each knows whether it is done.
  SetupStep = Struct.new(:key, :name, :done, :blocked_by, keyword_init: true) do
    def done? = done
    def blocked? = blocked_by.present?
  end

  def setup_steps
    [
      SetupStep.new(key: "people", name: "People", done: people.exists?),
      SetupStep.new(key: "routines", name: "Routines", done: routines.exists?),
      SetupStep.new(key: "chores", name: "Chores", done: chores.exists?, blocked_by: (routines.exists? ? nil : "routines")),
      SetupStep.new(key: "calendars", name: "Calendars", done: calendar_sources.exists?),
      SetupStep.new(key: "stores", name: "Stores", done: stores.exists?),
      SetupStep.new(key: "pins", name: "PINs", done: people.where(kid: false).where.not(pin_digest: nil).exists?),
      SetupStep.new(key: "screen", name: "Screen", done: screens.where.not(enrolled_at: nil).exists?)
    ]
  end

  def setup_complete?
    setup_steps.all?(&:done?)
  end

  # ---------------------------------------------------------------- sign-in (plan: Decisions)
  # Who may ask for a login code: a member with that email on their person, an existing login
  # (a fresh start removes people, not logins), or anyone at all while the household has no
  # logins yet (the owner's first sign-in).
  def login_allowed?(email)
    email = email.to_s.strip.downcase
    return false if email.blank?
    users.none? || people.exists?(email: email) || users.joins(:identity).exists?(identities: { email: email })
  end

  # The adult whose PIN this is, for unlocking from the frame (plan: gap review); nil otherwise.
  def adult_for_pin(pin)
    return nil if pin.blank?
    people.where(kid: false).where.not(pin_digest: nil).detect { |p| p.authenticate_pin(pin.to_s) }
  end

  # The person a login belongs to, by email.
  def member_for(user)
    people.find_by(email: user.email)
  end

  def latest_weather
    weather_reports.order(fetched_at: :desc).first
  end

  private

  def reload_screens
    Turbo::StreamsChannel.broadcast_action_to(self, action: "reload", attributes: { origin: Current.page_token })
  end
end
