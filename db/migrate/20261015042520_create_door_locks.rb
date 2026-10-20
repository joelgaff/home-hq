class CreateDoorLocks < ActiveRecord::Migration[8.1]
  def change
    create_table :door_locks do |t|
      t.boolean :locked, null: false, default: true

      t.timestamps
    end
  end
end
