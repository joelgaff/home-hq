# Settings → Home (plan: milestone 5): the rooms, devices, scenes, climate, media and cameras on
# one page, an import of what the hub knows, and a clear for the demo home.
class Settings::HomeController < Settings::BaseController
  def show
    @rooms = @household.rooms.includes(devices: :deviceable)
    @unplaced = @household.devices.where(room_id: nil).includes(:deviceable)
    @scenes = @household.scenes.includes(scene_settings: :device)
  end

  def import
    counts = @household.import_from_hub!
    saved(settings_home_path, "Imported #{counts[:devices]} devices, #{counts[:climate]} thermostat, #{counts[:media]} media player, #{counts[:cameras]} cameras from Home Assistant.")
  end

  def destroy
    @household.clear_home!
    saved(settings_home_path, "The home is cleared. Import from Home Assistant or add rooms and devices.")
  end
end
