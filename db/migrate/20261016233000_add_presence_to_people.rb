class AddPresenceToPeople < ActiveRecord::Migration[8.0]
  def change
    # The hub's person entity behind someone's presence (plan: Integrations: presence, ETA), and
    # their last known position for the ETA when away.
    change_table :people, bulk: true do |t|
      t.string :presence_entity
      t.decimal :presence_latitude, precision: 9, scale: 6
      t.decimal :presence_longitude, precision: 9, scale: 6
    end
  end
end
