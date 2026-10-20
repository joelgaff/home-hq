class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :identity, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
