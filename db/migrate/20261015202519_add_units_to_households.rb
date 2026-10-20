class AddUnitsToHouseholds < ActiveRecord::Migration[8.1]
  def change
    # Units and clock are settings (plan: Our instance). Wes's demo data is in °C; the thresholds
    # and thermostat steps follow the unit.
    add_column :households, :temperature_unit, :string, null: false, default: "c"
    add_column :households, :clock_format, :string, null: false, default: "12"
  end
end
