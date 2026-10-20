# Device patches and the device sheets (ui-spec §1.6). A patch either lands (tile re-rendered,
# confirmed) or is refused (tile re-rendered in its old state, red toast): Wes's optimistic
# contract, which the Home Assistant bridge will honour the same way.
class DevicesController < ApplicationController
  include ControlChanges

  PATCH_KEYS = %i[on level position locked state].freeze

  # The Lights / Security sheets.
  def index
    kind = params[:kind] == "security" ? "security" : "lights"
    @devices = kind == "lights" ? @household.devices.lights.includes(:deviceable, :room).sort_by { |d| d.on? ? 0 : 1 }
                                : (@household.devices.locks + @household.devices.garages).sort_by(&:position)
    render partial: "devices/#{kind}", layout: false
  end

  def update
    device = @household.devices.includes(:deviceable).find(params[:id])
    patch = params.permit(*PATCH_KEYS).to_h.symbolize_keys
    patch[:on] = cast_bool(patch[:on]) if patch.key?(:on)
    patch[:locked] = cast_bool(patch[:locked]) if patch.key?(:locked)
    if unlocking?(device, patch)
      if current_screen
        adult = @household.adult_for_pin(params[:pin])
        return render_pin_pad(device, patch, wrong: params[:pin].present?) unless adult
        Current.pin_person = adult
      elsif current_user&.person&.kid?
        return render_changes(devices: [ device ], toast: { html: "Ask an adult to unlock <b>#{ERB::Util.html_escape(device.name)}</b>", tone: "error", icon: "lock" })
      end
    end
    if device.apply(patch)
      @household.update!(active_scene: nil)
      RelockJob.set(wait: Device::RELOCK_AFTER).perform_later(device.id) if device.door_lock? && patch[:locked] == false && params[:relock].present?
      render_changes(devices: [ device.reload ], toast: landed_toast(device, patch))
    else
      render_changes(devices: [ device ], toast: { html: "Couldn’t reach <b>#{ERB::Util.html_escape(device.name)}</b> · it may be offline", tone: "error", icon: "bolt" })
    end
  end

  # The slide-to-confirm sheet for the garage.
  def garage
    @device = @household.devices.garages.find(params[:id])
    render partial: "devices/garage", layout: false
  end

  private

  # A lock opening or the garage opening needs an adult (plan: gap review). Locking never does.
  def unlocking?(device, patch)
    (device.door_lock? && patch[:locked] == false) || (device.garage_door? && patch[:state] == "opening")
  end

  # The PIN pad in the sheet, with the patch to replay; the tile goes back to its real state.
  def render_pin_pad(device, patch, wrong:)
    @device, @patch, @wrong = device, patch, wrong
    @devices = [ device ]
    render "devices/pin"
  end

  def cast_bool(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def landed_toast(device, patch)
    if patch.key?(:locked) && !patch[:locked]
      { html: "<b>#{ERB::Util.html_escape(device.name)}</b> unlocked", icon: "unlock" }
    elsif %w[open closed].include?(patch[:state])
      { html: "Garage #{patch[:state]}", icon: "garage", ms: 2500 }
    end
  end
end
