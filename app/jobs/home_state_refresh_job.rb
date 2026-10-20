# A full read of the hub's states every few minutes (plan: milestone 5), so a missed event never
# leaves a tile wrong for long; the listener carries the live changes in between.
class HomeStateRefreshJob < ApplicationJob
  queue_as :default

  def perform
    return unless HomeAssistant.configured?
    HomeAssistant::StateSync.forget_unit!
    Household.find_each do |household|
      Current.household = household
      Time.use_zone(household.time_zone) { HomeAssistant::StateSync.refresh(household) }
    rescue *HomeAssistant::Commands::FAILURES => e
      Rails.logger.warn "Home state refresh for #{household.name} failed: #{e.message}"
    ensure
      Current.household = nil
    end
  end
end
