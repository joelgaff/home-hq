class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :icon
      t.boolean :locks_all, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
