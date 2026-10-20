class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :household, null: false, foreign_key: true
      t.references :person, null: true, foreign_key: true
      t.string :image_key, null: false
      t.string :orientation, null: false, default: "landscape"
      t.date :taken_on, null: false
      t.string :place
      t.string :album
      t.boolean :favorite, null: false, default: false

      t.timestamps
    end
  end
end
