class CreateCalendarSources < ActiveRecord::Migration[8.0]
  def change
    # Read-only calendar feeds (plan: Calendars, pluggable sources). Events synced from a source
    # carry its id and the feed's UID (per occurrence); a manual people override survives re-syncs.
    create_table :calendar_sources do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false, default: "ics"
      t.string :url, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :refresh_minutes, null: false, default: 5
      t.datetime :synced_at
      t.string :last_error
      t.timestamps
    end
    create_table :calendar_source_people do |t|
      t.references :calendar_source, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.timestamps
    end
    add_index :calendar_source_people, %i[calendar_source_id person_id], unique: true
    change_table :events, bulk: true do |t|
      t.references :calendar_source, foreign_key: true
      t.string :uid
      t.boolean :people_overridden, null: false, default: false
    end
    add_index :events, %i[calendar_source_id uid], unique: true
    # Names the family writes in event titles ("Skid karate"): whole-word matches, like the name.
    add_column :people, :nicknames, :string
  end
end
