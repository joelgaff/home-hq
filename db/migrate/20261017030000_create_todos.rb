class CreateTodos < ActiveRecord::Migration[8.0]
  def change
    # One-off to-dos (plan: People view): for a person or Anyone, optionally due on a day or at a
    # time, optionally worth stars for a kid; done is a timestamp.
    create_table :todos do |t|
      t.references :household, null: false, foreign_key: true
      t.references :person, foreign_key: true
      t.string :title, null: false
      t.date :due_on
      t.datetime :due_at
      t.integer :stars, null: false, default: 0
      t.datetime :done_at
      t.references :done_by, foreign_key: { to_table: :people }
      t.string :created_by
      t.timestamps
    end
    add_index :todos, %i[household_id due_on]
    add_reference :star_entries, :todo, foreign_key: true
  end
end
