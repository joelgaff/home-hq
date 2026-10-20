class AddWaterValveEntityToHouseholds < ActiveRecord::Migration[8.0]
  def change
    # The water main's hub entity, for the leak takeover's "hold to shut off water" (plan: milestone 6).
    add_column :households, :water_valve_entity, :string
  end
end
