class AddWeatherAndTravelSettings < ActiveRecord::Migration[8.0]
  def change
    # Home Assistant entities and the home address (plan: Integrations: weather, travel). The hub's
    # URL and token live in credentials or the environment, not here.
    change_table :households, bulk: true do |t|
      t.string :weather_entity
      t.string :home_address
      t.string :travel_region, null: false, default: "us"
    end
    # Where a report came from (the weather entity), nil for the seeded demo report.
    add_column :weather_reports, :source, :string
  end
end
