class CreateWeatherReports < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_reports do |t|
      t.references :household, null: false, foreign_key: true
      t.integer :high, null: false
      t.integer :low, null: false
      t.datetime :fetched_at

      t.timestamps
    end
  end
end
