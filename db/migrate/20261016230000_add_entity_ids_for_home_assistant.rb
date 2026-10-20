class AddEntityIdsForHomeAssistant < ActiveRecord::Migration[8.0]
  def change
    # The Home Assistant entity behind each thing (plan: milestone 5); nil for the demo data.
    add_column :devices, :entity_id, :string
    add_index :devices, %i[household_id entity_id], unique: true
    add_column :thermostats, :entity_id, :string
    add_column :media_players, :entity_id, :string
    add_column :cameras, :entity_id, :string
    add_column :scenes, :entity_id, :string
  end
end
