class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false
      t.string :ink, null: false, default: "#FFFFFF"
      t.boolean :kid, null: false, default: false
      t.boolean :home, null: false, default: false
      t.string :status
      t.integer :eta_minutes
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
