# What is playing on a speaker (ui-spec §1.6 "Now playing").
class MediaPlayer < ApplicationRecord
  include SyncsPieces

  belongs_to :household
  syncs_pieces :"control-media", :"control-sum"
  belongs_to :room, optional: true

  def room_name
    room&.name || "Speaker"
  end

  def art_url
    "https://picsum.photos/seed/#{art_key}/160/160"
  end

  # Play/pause; a mapped speaker asks the hub first and keeps its state when refused.
  def toggle!
    target = !playing?
    return false if entity_id.present? && HomeAssistant.configured? && !HomeAssistant::Commands.media_play(self, target)
    update!(playing: target)
  end
end
