class CreateCameras < ActiveRecord::Migration[8.1]
  def change
    create_table :cameras do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :image_key
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
