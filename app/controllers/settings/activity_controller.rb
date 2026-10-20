# Settings → Activity (plan: milestone 5): the audit log, newest first.
class Settings::ActivityController < Settings::BaseController
  def show
    @entries = @household.audit_entries.newest_first.limit(300)
  end
end
