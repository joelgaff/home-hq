class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :household, null: false, foreign_key: true
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, null: false, default: false
      t.string :location
      t.integer :travel_minutes
      t.text :notes
      t.string :demo_set

      t.timestamps
      t.index %i[household_id starts_at]
      t.index %i[household_id ends_at]
    end
  end
end
