class CreateSceneSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_settings do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :device, null: false, foreign_key: true
      t.integer :level, null: false, default: 0

      t.timestamps
    end
  end
end
