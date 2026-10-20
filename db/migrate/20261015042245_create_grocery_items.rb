class CreateGroceryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :grocery_items do |t|
      t.references :household, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, null: false, default: 1
      t.string :note
      t.datetime :checked_at
      t.datetime :cleared_at

      t.timestamps
    end
  end
end
