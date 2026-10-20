# The house thermostat (ui-spec §1.6): setpoint stepped and clamped by the household's unit;
# adjusting while off switches to heat. Degrees are whatever the household's unit is.
class Thermostat < ApplicationRecord
  MODES = %w[heat cool auto off].freeze

  include SyncsPieces

  belongs_to :household
  syncs_pieces :"control-climate", :"control-sum", :"today-status"

  validates :mode, inclusion: MODES

  # Steps and limits follow the household's unit: 0.5° between 15 and 28 °C, 1° between 60 and
  # 82 °F.
  delegate :thermostat_step, :thermostat_range, to: :household
  alias_method :step, :thermostat_step

  # Steps the setpoint; a mapped thermostat asks the hub first and keeps its state when refused.
  def adjust!(delta)
    target = (target_temperature + delta).clamp(thermostat_range.min, thermostat_range.max)
    new_mode = mode == "off" ? "heat" : mode
    if hub?
      return false unless HomeAssistant::Commands.thermostat_temperature(self, target)
      HomeAssistant::Commands.thermostat_mode(self, new_mode) if new_mode != mode
    end
    update!(target_temperature: target, mode: new_mode)
  end

  def set_mode!(new_mode)
    return false unless MODES.include?(new_mode)
    return false if hub? && !HomeAssistant::Commands.thermostat_mode(self, new_mode)
    update!(mode: new_mode)
  end

  def hub?
    entity_id.present? && HomeAssistant.configured?
  end

  def off? = mode == "off"

  def verb
    return "Off" if off?
    return "Heating" if target_temperature > current_temperature
    return "Cooling" if target_temperature < current_temperature
    "Holding"
  end

  # "21.5" or "28" (no trailing .0)
  def target_label
    format("%g", target_temperature)
  end

  def current_label
    format("%g", current_temperature)
  end

  # "Heating to 21.5°" for the summary card.
  def summary_line
    off? ? "System off" : "#{verb} to #{target_label}°"
  end
end
