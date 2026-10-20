class CreateChoreCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :chore_completions do |t|
      t.references :chore, null: false, foreign_key: true
      t.references :person, null: true, foreign_key: true
      t.date :completed_on, null: false

      t.timestamps
      t.index %i[chore_id completed_on]
    end
  end
end
