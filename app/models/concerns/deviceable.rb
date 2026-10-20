# Shared interface of the device types (ui-spec §1.6). Each type answers the tile questions and
# applies its own patch. The state readers fall back to a default for types without that column
# (a module included after the attribute methods would otherwise hide the real attribute).
module Deviceable
  extend ActiveSupport::Concern

  included do
    has_one :device, as: :deviceable, touch: true
  end

  def kind = self.class.name.underscore
  def on? = has_attribute?(:on) ? self[:on] : false
  def level = has_attribute?(:level) ? self[:level] : nil
  def position = has_attribute?(:position) ? self[:position] : nil
  def locked? = has_attribute?(:locked) ? self[:locked] : true
  def state = has_attribute?(:state) ? self[:state] : nil
  def secure? = true
  def warn? = false
  def fill_percent = 0

  # The attributes a scene snapshot saves and restores.
  def snapshot
    attributes.slice(*self.class.snapshot_attributes.map(&:to_s))
  end

  def restore(values)
    update!(values.slice(*self.class.snapshot_attributes.map(&:to_s)))
  end

  class_methods do
    def snapshot_attributes
      []
    end
  end
end
