# The speaker's hub entity and room (plan: milestone 5).
class Settings::MediaPlayersController < Settings::BaseController
  before_action { @entities = HomeAssistant.configured? ? HomeAssistant.entities(%w[media_player]) : [] }

  def edit
    @player = @household.media_player || @household.build_media_player
  end

  def update
    @player = @household.media_player || @household.build_media_player
    permitted = params.expect(media_player: [ :entity_id, :room_id ])
    permitted[:room_id] = @household.rooms.find_by(id: permitted[:room_id])&.id if permitted.key?(:room_id)
    @player.update(permitted) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end
end
