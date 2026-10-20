# Settings (plan: milestone 3): the household itself (name, zone, units, clock, week start, the chores pause)
# and the doorway to every list. Adults only.
class SettingsController < ApplicationController
  before_action :require_adult
  layout "application"

  def show
    @household = Current.household
  end

  def update
    @household = Current.household
    if @household.update(params.expect(household: [ :name, :time_zone, :temperature_unit, :clock_format, :week_start, :chores_paused_until, :weather_entity, :weather_location, :rain_keywords, :home_address, :travel_region, :water_valve_entity, immich_album_ids: [] ]).tap { |h| h[:immich_album_ids] = Array(h[:immich_album_ids]).compact_blank if h.key?(:immich_album_ids) })
      WeatherSyncJob.perform_later if @household.saved_change_to_weather_location? && @household.weather_located?
      redirect_to settings_path, notice: "Saved."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
