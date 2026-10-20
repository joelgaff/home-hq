# Drive times from home to today's upcoming events, through Home Assistant's Waze service (plan:
# Integrations; second gap review): checked every 10 minutes within two hours of leaving, hourly
# otherwise, one lookup per destination, only for synced events with a location. The leave-by and the Today hero follow.
class TravelSyncJob < ApplicationJob
  queue_as :default

  NEAR = 2.hours
  NEAR_EVERY = 10.minutes
  FAR_EVERY = 1.hour

  def perform
    return unless HomeAssistant.configured?
    Household.where.not(home_address: [ nil, "" ]).find_each do |household|
      Current.household = household
      Time.use_zone(household.time_zone) do
        Pieces.batch(origin: nil) do
          now = Time.current
          @routes = {}
          candidates(household, now).each { |event| refresh(event, household) if due?(event, now) }
          etas(household)
        end
      end
    ensure
      Current.household = nil
    end
  end

  private

  def candidates(household, now)
    household.events.where.not(calendar_source_id: nil).where.not(location: [ nil, "" ]).where(all_day: false)
      .where(starts_at: now..now.end_of_day).order(:starts_at)
  end

  def due?(event, now)
    return true if event.travel_checked_at.nil?
    every = event.leave_by - now <= NEAR ? NEAR_EVERY : FAR_EVERY
    event.travel_checked_at <= now - every
  end

  # An adult away with a known position gets an ETA home (plan: Integrations: presence, ETA);
  # at home it clears.
  def etas(household)
    household.people.where(kid: false).where.not(presence_entity: [ nil, "" ]).find_each do |person|
      if person.home?
        person.update!(eta_minutes: nil) if person.eta_minutes
      elsif person.presence_latitude && person.presence_longitude
        response = HomeAssistant.call("waze_travel_time", "get_travel_times",
          { origin: "#{person.presence_latitude.to_f},#{person.presence_longitude.to_f}", destination: household.home_address, region: household.travel_region })
        minutes = response.dig("service_response", "routes")&.first&.dig("duration")
        person.update!(eta_minutes: minutes.to_f.round) if minutes
      end
    rescue *HomeAssistant::FAILURES => e
      Rails.logger.warn "ETA for #{person.name} failed: #{e.message}"
    end
  end

  # One lookup per destination per run (events at the same place share it).
  def refresh(event, household)
    key = event.location.to_s.strip.squeeze(" ").downcase
    minutes = @routes.fetch(key) do
      response = HomeAssistant.call("waze_travel_time", "get_travel_times",
        { origin: household.home_address, destination: event.location.strip, region: household.travel_region })
      route = response.dig("service_response", "routes")&.first
      @routes[key] = route && route["duration"] ? route["duration"].to_f.round : nil
    end
    return unless minutes
    event.update!(travel_minutes: minutes, travel_checked_at: Time.current)
  rescue HomeAssistant::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED => e
    Rails.logger.warn "Travel time for #{event.title} failed: #{e.message}"
  end
end
