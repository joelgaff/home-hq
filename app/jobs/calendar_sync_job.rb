# Syncs every calendar source that is due (plan: Integrations, calendars: every 5 minutes), in
# its household's zone, and tells the screens once per household.
class CalendarSyncJob < ApplicationJob
  queue_as :default

  def perform
    CalendarSource.enabled.includes(:household).group_by(&:household).each do |household, sources|
      Current.household = household
      Time.use_zone(household.time_zone) do
        Pieces.batch(origin: nil) { sources.select(&:due?).each(&:sync!) }
      end
    ensure
      Current.household = nil
    end
  end
end
