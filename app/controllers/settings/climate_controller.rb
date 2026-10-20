# The thermostat's hub entity (plan: milestone 5); the thermostat row is created when first mapped.
class Settings::ClimateController < Settings::BaseController
  before_action { @entities = HomeAssistant.configured? ? HomeAssistant.entities(%w[climate]) : [] }

  def edit
    @thermostat = @household.thermostat || @household.build_thermostat(current_temperature: 20, target_temperature: 20, mode: "off")
  end

  def update
    @thermostat = @household.thermostat || @household.build_thermostat(current_temperature: 20, target_temperature: 20, mode: "off")
    @thermostat.update(params.expect(thermostat: [ :entity_id ])) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end
end
