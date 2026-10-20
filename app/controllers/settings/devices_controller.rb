# Devices mapped to hub entities (plan: milestone 5). The type is picked once, at creation.
class Settings::DevicesController < Settings::BaseController
  before_action :set_device, only: %i[edit update destroy move]
  before_action { @entities = HomeAssistant.configured? ? HomeAssistant.entities(Device::DOMAINS.values.flatten.uniq) : [] }

  def index = redirect_to(settings_home_path)

  def new
    @device = @household.devices.new(deviceable: Light.new)
  end

  def create
    kind = params.dig(:device, :kind).to_s
    unless Device::TYPES.include?(kind)
      @device = @household.devices.new(device_params.merge(deviceable: Light.new))
      @device.errors.add(:base, "Pick a device type")
      return render(:new, status: :unprocessable_entity)
    end
    @device = @household.devices.new(device_params.merge(deviceable: kind.constantize.new))
    @device.save ? saved(settings_home_path, "#{@device.name} added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @device.update(device_params) ? saved(settings_home_path) : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @device.destroy
    saved(settings_home_path, "#{@device.name} removed.")
  end

  def move
    @device.move!(params[:direction], @household.devices)
    saved(settings_home_path)
  end

  private

  def set_device = @device = @household.devices.includes(:deviceable).find(params[:id])

  def device_params
    permitted = params.expect(device: [ :name, :room_id, :entity_id ])
    permitted[:room_id] = @household.rooms.find_by(id: permitted[:room_id])&.id if permitted.key?(:room_id)
    permitted
  end
end
