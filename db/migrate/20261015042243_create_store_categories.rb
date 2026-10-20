class CreateStoreCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :store_categories do |t|
      t.references :store, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
      t.index %i[store_id category_id], unique: true
    end
  end
end
