class CreateChores < ActiveRecord::Migration[8.1]
  def change
    create_table :chores do |t|
      t.references :household, null: false, foreign_key: true
      t.references :routine, null: false, foreign_key: true
      t.references :person, null: true, foreign_key: true
      t.string :title, null: false
      t.string :emoji
      t.integer :stars, null: false, default: 0
      t.boolean :overdue, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
