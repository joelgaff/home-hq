class CreateAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendees do |t|
      t.references :event, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true

      t.timestamps
      t.index %i[event_id person_id], unique: true
    end
  end
end
