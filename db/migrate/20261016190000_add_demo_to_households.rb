class AddDemoToHouseholds < ActiveRecord::Migration[8.0]
  def change
    # The demo tools (drawer, time presets, fake alerts, the startup tip) show only on a demo
    # household: the seeds set it, a fresh start clears it.
    add_column :households, :demo, :boolean, null: false, default: false
  end
end
