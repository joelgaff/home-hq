# Settings → Calendars (plan: Calendars, pluggable sources): the household's feeds, who each one
# is for, and a "Sync now" that fetches it on the spot.
class Settings::CalendarSourcesController < Settings::BaseController
  before_action :set_source, only: %i[edit update destroy sync]

  def index
    @sources = @household.calendar_sources.includes(:people).order(:created_at)
  end

  def new
    @source = @household.calendar_sources.new
  end

  def create
    @source = @household.calendar_sources.new(source_params)
    @source.save ? saved(settings_calendar_sources_path, "#{@source.name} added. It syncs within a few minutes, or sync it now.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @source.update(source_params) ? saved(settings_calendar_sources_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @source.destroy
    saved(settings_calendar_sources_path, "#{@source.name} removed, with its events.")
  end

  def sync
    if @source.sync!
      saved(settings_calendar_sources_path, "#{@source.name} synced: #{@source.events.count} events.")
    else
      redirect_to settings_calendar_sources_path, alert: "#{@source.name} could not be read: #{@source.last_error}"
    end
  end

  private

  def set_source
    @source = @household.calendar_sources.find(params[:id])
  end

  def source_params
    permitted = params.expect(calendar_source: [ :name, :url, :enabled, :refresh_minutes, person_ids: [] ])
    permitted[:person_ids] = @household.people.where(id: permitted[:person_ids]).ids if permitted.key?(:person_ids)
    permitted
  end
end
