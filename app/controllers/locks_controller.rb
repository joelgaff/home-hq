# "Lock all doors" from the Security sheet (ui-spec §1.6).
class LocksController < ApplicationController
  include ControlChanges

  def create
    locks = @household.lock_all!
    render_changes(devices: locks, toast: { html: "All doors locked", icon: "lock" })
  end
end
