class CreateThermostats < ActiveRecord::Migration[8.1]
  def change
    create_table :thermostats do |t|
      t.references :household, null: false, foreign_key: true
      t.decimal :current_temperature, precision: 4, scale: 1, null: false
      t.decimal :target_temperature, precision: 4, scale: 1, null: false
      t.string :mode, null: false, default: "heat"
      t.integer :humidity
      t.decimal :outside_temperature, precision: 4, scale: 1

      t.timestamps
    end
  end
end
