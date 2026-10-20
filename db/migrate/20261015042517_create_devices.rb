class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.references :household, null: false, foreign_key: true
      t.references :room, null: true, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :flaky, null: false, default: false
      t.references :deviceable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
