class Current < ActiveSupport::CurrentAttributes
  # Single-tenant today; repoint resolution when multi-tenancy activates.
  attribute :household
  attribute :user
  attribute :screen

  # The dashboard's idea of "now" in the household's time zone. The demo drawer can shift it
  # (a dev tool; the frame itself has no reliable clock, so the server is the source of time).
  attribute :clock_offset
  # The demo drawer's calendar data mode: nil (normal), "empty" or "busy" (ui-spec §1.9).
  attribute :calendar_mode
  # Live sync (Pieces): the writer's page token (so it skips its own broadcast) and the pieces
  # collected during the request.
  attribute :page_token
  attribute :pieces_batch
  # Every chore of the household with its routine and today's completions, loaded once per
  # request by Household#loaded_chores; chore and completion writes clear it.
  attribute :chores_cache
  # The adult whose PIN authorised the current unlock from the frame (plan: gap review).
  attribute :pin_person

  def now
    Time.current + (clock_offset || 0)
  end
end
