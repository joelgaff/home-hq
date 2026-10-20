class CreateSceneActivations < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_activations do |t|
      t.references :household, null: false, foreign_key: true
      t.references :scene, null: false, foreign_key: true
      t.json :snapshot

      t.timestamps
    end
  end
end
