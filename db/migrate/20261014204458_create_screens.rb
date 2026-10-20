class CreateScreens < ActiveRecord::Migration[8.1]
  def change
    create_table :screens do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :enrollment_token
      t.string :session_token
      t.datetime :enrolled_at

      t.timestamps
    end
    add_index :screens, :enrollment_token, unique: true
    add_index :screens, :session_token, unique: true
  end
end
