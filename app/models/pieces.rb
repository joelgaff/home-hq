# Live sync between screens (plan: milestone 3; spike rules in Decisions). A write names the
# pieces of the dashboard it changed, by their stable DOM ids. The ids are collected for the
# length of the request and broadcast once, as a "pieces" stream action, to the household;
# every screen but the writer then fetches those pieces from PiecesController, rendered for
# itself (its layout, its session, its time). Nothing bigger than a piece ever travels.
module Pieces
  # Piece id → the partial that renders it (the controller supplies locals from the asker's
  # context: the chores routine, the shopping store and drawer).
  REGISTRY = {
    "today-clock" => "today/clock", "today-weather" => "today/weather", "today-presence" => "today/presence",
    "today-hero" => "today/hero", "today-lanes" => "today/lanes", "today-agenda" => "today/agenda",
    "today-chores" => "today/chores", "today-shopping" => "today/shopping", "today-status" => "today/status",
    "chores" => "chores/chores",
    "calendar" => "calendar/calendar",
    "people" => "people/people",
    "shopping" => "shopping/list", "shopping-side" => "shopping/side",
    "control-sum" => "control/summary", "control-scenes" => "control/scenes", "control-rooms" => "control/rooms",
    "control-climate" => "control/climate", "control-media" => "control/media"
  }.freeze

  class << self
    # Called from model callbacks. Inside a request the ids wait for the request's single
    # broadcast; outside one (a job, the console) they go out at once.
    def changed(household, *ids)
      ids = ids.flatten.map(&:to_s)
      unknown = ids - REGISTRY.keys
      raise ArgumentError, "unknown pieces: #{unknown.join(', ')}" if unknown.any?
      if Current.pieces_batch
        Current.pieces_batch[household] ||= Set.new
        Current.pieces_batch[household].merge(ids)
      else
        broadcast(household, ids, origin: nil)
      end
    end

    # Wraps a request: everything changed inside goes out as one broadcast per household.
    def batch(origin:)
      Current.pieces_batch = {}
      yield
    ensure
      batch = Current.pieces_batch
      Current.pieces_batch = nil
      batch&.each { |household, ids| broadcast(household, ids.to_a, origin: origin) }
    end

    def broadcast(household, ids, origin:)
      return if ids.empty?
      Turbo::StreamsChannel.broadcast_action_to(household, action: "pieces", targets: ids.sort.join(","), attributes: { origin: origin })
    end
  end
end
