# Now playing: play / pause (ui-spec §1.6).
class MediaPlayersController < ApplicationController
  def update
    @household = Current.household
    @household.media_player.toggle!
    render :changed
  end
end
