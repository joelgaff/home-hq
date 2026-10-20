class CreateHourlyForecasts < ActiveRecord::Migration[8.1]
  def change
    create_table :hourly_forecasts do |t|
      t.references :weather_report, null: false, foreign_key: true
      t.integer :hour, null: false
      t.integer :temperature, null: false
      t.string :condition, null: false
      t.integer :precipitation_chance, null: false, default: 0

      t.timestamps
      t.index %i[weather_report_id hour], unique: true
    end
  end
end
