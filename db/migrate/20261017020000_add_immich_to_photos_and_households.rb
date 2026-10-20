class AddImmichToPhotosAndHouseholds < ActiveRecord::Migration[8.0]
  def change
    # Photos from Immich (plan: milestone 7): the asset behind a photo, and the albums a household shows.
    add_column :photos, :immich_id, :string
    add_index :photos, %i[household_id immich_id], unique: true
    add_column :households, :immich_album_ids, :json, null: false, default: []
  end
end
