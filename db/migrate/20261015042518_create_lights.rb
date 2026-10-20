class CreateLights < ActiveRecord::Migration[8.1]
  def change
    create_table :lights do |t|
      t.boolean :on, null: false, default: false
      t.integer :level, null: false, default: 100

      t.timestamps
    end
  end
end
