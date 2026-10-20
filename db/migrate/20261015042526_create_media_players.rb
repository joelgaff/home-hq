class CreateMediaPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :media_players do |t|
      t.references :household, null: false, foreign_key: true
      t.references :room, null: true, foreign_key: true
      t.string :title
      t.string :artist
      t.boolean :playing, null: false, default: false
      t.string :art_key

      t.timestamps
    end
  end
end
