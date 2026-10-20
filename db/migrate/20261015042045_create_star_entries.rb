class CreateStarEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :star_entries do |t|
      t.references :person, null: false, foreign_key: true
      t.integer :amount, null: false
      t.references :chore_completion, null: true, foreign_key: true
      t.string :note

      t.timestamps
    end
  end
end
