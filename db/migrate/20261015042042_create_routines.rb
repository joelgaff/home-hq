class CreateRoutines < ActiveRecord::Migration[8.1]
  def change
    create_table :routines do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :range_label
      t.integer :from_hour, null: false
      t.integer :to_hour, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
