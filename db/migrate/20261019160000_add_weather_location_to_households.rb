class AddWeatherLocationToHouseholds < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :weather_location, :string
    add_column :households, :weather_latitude, :decimal, precision: 8, scale: 5
    add_column :households, :weather_longitude, :decimal, precision: 8, scale: 5
  end
end
