# Answers for Home control writes (ui-spec §1.6): the tiles that changed, their room counts,
# the summary cards, the Today card, the scenes row when asked, and a toast when there is one.
module ControlChanges
  extend ActiveSupport::Concern

  included do
    before_action { @household = Current.household }
  end

  private

  def render_changes(devices:, toast: nil, scenes: false)
    @devices = devices
    @toast = toast
    @scenes = scenes
    render "devices/changed"
  end
end
