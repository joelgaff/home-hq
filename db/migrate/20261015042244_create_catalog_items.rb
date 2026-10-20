class CreateCatalogItems < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_items do |t|
      t.references :household, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.string :name, null: false
      t.boolean :usual, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
