# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_170000) do
  create_table "attendees", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "person_id"], name: "index_attendees_on_event_id_and_person_id", unique: true
    t.index ["event_id"], name: "index_attendees_on_event_id"
    t.index ["person_id"], name: "index_attendees_on_person_id"
  end

  create_table "audit_entries", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "action", null: false
    t.string "actor_type"
    t.integer "actor_id"
    t.string "actor_name"
    t.string "subject_type"
    t.integer "subject_id"
    t.string "subject_name"
    t.json "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_audit_entries_on_actor"
    t.index ["household_id", "created_at"], name: "index_audit_entries_on_household_id_and_created_at"
    t.index ["household_id"], name: "index_audit_entries_on_household_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_entries_on_subject"
  end

  create_table "blinds", force: :cascade do |t|
    t.integer "position", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calendar_source_people", force: :cascade do |t|
    t.integer "calendar_source_id", null: false
    t.integer "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_source_id", "person_id"], name: "idx_on_calendar_source_id_person_id_e29be8ff88", unique: true
    t.index ["calendar_source_id"], name: "index_calendar_source_people_on_calendar_source_id"
    t.index ["person_id"], name: "index_calendar_source_people_on_person_id"
  end

  create_table "calendar_sources", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "kind", default: "ics", null: false
    t.string "url", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "refresh_minutes", default: 5, null: false
    t.datetime "synced_at"
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_calendar_sources_on_household_id"
  end

  create_table "cameras", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "image_key"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_id"
    t.index ["household_id"], name: "index_cameras_on_household_id"
  end

  create_table "catalog_items", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "category_id"
    t.string "name", null: false
    t.boolean "usual", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_catalog_items_on_category_id"
    t.index ["household_id"], name: "index_catalog_items_on_household_id"
  end

  create_table "categories", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_categories_on_household_id"
  end

  create_table "chore_completions", force: :cascade do |t|
    t.integer "chore_id", null: false
    t.integer "person_id"
    t.date "completed_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chore_id", "completed_on"], name: "index_chore_completions_on_chore_id_and_completed_on"
    t.index ["chore_id"], name: "index_chore_completions_on_chore_id"
    t.index ["person_id"], name: "index_chore_completions_on_person_id"
  end

  create_table "chores", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "routine_id", null: false
    t.integer "person_id"
    t.string "title", null: false
    t.string "emoji"
    t.integer "stars", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weekdays"
    t.index ["household_id"], name: "index_chores_on_household_id"
    t.index ["person_id"], name: "index_chores_on_person_id"
    t.index ["routine_id"], name: "index_chores_on_routine_id"
  end

  create_table "devices", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "room_id"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "flaky", default: false, null: false
    t.string "deviceable_type", null: false
    t.integer "deviceable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_id"
    t.index ["deviceable_type", "deviceable_id"], name: "index_devices_on_deviceable"
    t.index ["household_id", "entity_id"], name: "index_devices_on_household_id_and_entity_id", unique: true
    t.index ["household_id"], name: "index_devices_on_household_id"
    t.index ["room_id"], name: "index_devices_on_room_id"
  end

  create_table "door_locks", force: :cascade do |t|
    t.boolean "locked", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "title", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.boolean "all_day", default: false, null: false
    t.string "location"
    t.integer "travel_minutes"
    t.text "notes"
    t.string "demo_set"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "calendar_source_id"
    t.string "uid"
    t.boolean "people_overridden", default: false, null: false
    t.datetime "travel_checked_at"
    t.index ["calendar_source_id", "uid"], name: "index_events_on_calendar_source_id_and_uid", unique: true
    t.index ["calendar_source_id"], name: "index_events_on_calendar_source_id"
    t.index ["household_id", "ends_at"], name: "index_events_on_household_id_and_ends_at"
    t.index ["household_id", "starts_at"], name: "index_events_on_household_id_and_starts_at"
    t.index ["household_id"], name: "index_events_on_household_id"
  end

  create_table "garage_doors", force: :cascade do |t|
    t.string "state", default: "closed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "grocery_items", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "category_id"
    t.integer "store_id", null: false
    t.string "name", null: false
    t.integer "quantity", default: 1, null: false
    t.string "note"
    t.datetime "checked_at"
    t.datetime "cleared_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_grocery_items_on_category_id"
    t.index ["household_id"], name: "index_grocery_items_on_household_id"
    t.index ["store_id"], name: "index_grocery_items_on_store_id"
  end

  create_table "home_alerts", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "kind", null: false
    t.string "message"
    t.integer "camera_id"
    t.integer "device_id"
    t.json "details", default: {}, null: false
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["camera_id"], name: "index_home_alerts_on_camera_id"
    t.index ["device_id"], name: "index_home_alerts_on_device_id"
    t.index ["household_id", "created_at"], name: "index_home_alerts_on_household_id_and_created_at"
    t.index ["household_id"], name: "index_home_alerts_on_household_id"
  end

  create_table "hourly_forecasts", force: :cascade do |t|
    t.integer "weather_report_id", null: false
    t.integer "hour", null: false
    t.integer "temperature", null: false
    t.string "condition", null: false
    t.integer "precipitation_chance", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["weather_report_id", "hour"], name: "index_hourly_forecasts_on_weather_report_id_and_hour", unique: true
    t.index ["weather_report_id"], name: "index_hourly_forecasts_on_weather_report_id"
  end

  create_table "households", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "UTC", null: false
    t.integer "active_scene_id"
    t.date "chores_paused_until"
    t.string "temperature_unit", default: "c", null: false
    t.string "clock_format", default: "12", null: false
    t.string "week_start", default: "monday", null: false
    t.boolean "demo", default: false, null: false
    t.string "weather_entity"
    t.string "home_address"
    t.string "travel_region", default: "us", null: false
    t.string "water_valve_entity"
    t.json "immich_album_ids", default: [], null: false
    t.string "weather_location"
    t.decimal "weather_latitude", precision: 8, scale: 5
    t.decimal "weather_longitude", precision: 8, scale: 5
    t.string "rain_keywords", default: "soccer, practice, game, hike, park", null: false
    t.index ["active_scene_id"], name: "index_households_on_active_scene_id"
  end

  create_table "identities", force: :cascade do |t|
    t.string "email"
    t.string "login_code_digest"
    t.datetime "login_code_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_identities_on_email", unique: true
  end

  create_table "lights", force: :cascade do |t|
    t.boolean "on", default: false, null: false
    t.integer "level", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_players", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "room_id"
    t.string "title"
    t.string "artist"
    t.boolean "playing", default: false, null: false
    t.string "art_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_id"
    t.index ["household_id"], name: "index_media_players_on_household_id"
    t.index ["room_id"], name: "index_media_players_on_room_id"
  end

  create_table "people", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "color", null: false
    t.string "ink", default: "#FFFFFF", null: false
    t.boolean "kid", default: false, null: false
    t.boolean "home", default: false, null: false
    t.string "status"
    t.integer "eta_minutes"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "email"
    t.string "nicknames"
    t.string "presence_entity"
    t.decimal "presence_latitude", precision: 9, scale: 6
    t.decimal "presence_longitude", precision: 9, scale: 6
    t.string "pin_digest"
    t.index ["household_id", "email"], name: "index_people_on_household_id_and_email", unique: true
    t.index ["household_id"], name: "index_people_on_household_id"
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "photos", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "person_id"
    t.string "image_key", null: false
    t.string "orientation", default: "landscape", null: false
    t.date "taken_on", null: false
    t.string "place"
    t.string "album"
    t.boolean "favorite", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "immich_id"
    t.index ["household_id", "immich_id"], name: "index_photos_on_household_id_and_immich_id", unique: true
    t.index ["household_id"], name: "index_photos_on_household_id"
    t.index ["person_id"], name: "index_photos_on_person_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_rooms_on_household_id"
  end

  create_table "routines", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "range_label"
    t.integer "from_hour", null: false
    t.integer "to_hour", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "weekdays"
    t.index ["household_id"], name: "index_routines_on_household_id"
  end

  create_table "scene_activations", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "scene_id"
    t.json "snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_scene_activations_on_household_id"
    t.index ["scene_id"], name: "index_scene_activations_on_scene_id"
  end

  create_table "scene_settings", force: :cascade do |t|
    t.integer "scene_id", null: false
    t.integer "device_id", null: false
    t.integer "level", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_scene_settings_on_device_id"
    t.index ["scene_id"], name: "index_scene_settings_on_scene_id"
  end

  create_table "scenes", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "icon"
    t.boolean "locks_all", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_id"
    t.index ["household_id"], name: "index_scenes_on_household_id"
  end

  create_table "screens", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.string "enrollment_token"
    t.string "session_token"
    t.datetime "enrolled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "night_from", default: 22, null: false
    t.integer "night_to", default: 6, null: false
    t.string "night_style", default: "off", null: false
    t.string "default_view", default: "home", null: false
    t.integer "reload_hour", default: 3
    t.index ["enrollment_token"], name: "index_screens_on_enrollment_token", unique: true
    t.index ["household_id"], name: "index_screens_on_household_id"
    t.index ["session_token"], name: "index_screens_on_session_token", unique: true
  end

  create_table "star_entries", force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "amount", null: false
    t.integer "chore_completion_id"
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "todo_id"
    t.index ["chore_completion_id"], name: "index_star_entries_on_chore_completion_id"
    t.index ["person_id"], name: "index_star_entries_on_person_id"
    t.index ["todo_id"], name: "index_star_entries_on_todo_id"
  end

  create_table "store_categories", force: :cascade do |t|
    t.integer "store_id", null: false
    t.integer "category_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_store_categories_on_category_id"
    t.index ["store_id", "category_id"], name: "index_store_categories_on_store_id_and_category_id", unique: true
    t.index ["store_id"], name: "index_store_categories_on_store_id"
  end

  create_table "stores", force: :cascade do |t|
    t.integer "household_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_stores_on_household_id"
  end

  create_table "thermostats", force: :cascade do |t|
    t.integer "household_id", null: false
    t.decimal "current_temperature", precision: 4, scale: 1, null: false
    t.decimal "target_temperature", precision: 4, scale: 1, null: false
    t.string "mode", default: "heat", null: false
    t.integer "humidity"
    t.decimal "outside_temperature", precision: 4, scale: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entity_id"
    t.index ["household_id"], name: "index_thermostats_on_household_id"
  end

  create_table "todos", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "person_id"
    t.string "title", null: false
    t.date "due_on"
    t.datetime "due_at"
    t.integer "stars", default: 0, null: false
    t.datetime "done_at"
    t.integer "done_by_id"
    t.string "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["done_by_id"], name: "index_todos_on_done_by_id"
    t.index ["household_id", "due_on"], name: "index_todos_on_household_id_and_due_on"
    t.index ["household_id"], name: "index_todos_on_household_id"
    t.index ["person_id"], name: "index_todos_on_person_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "identity_id", null: false
    t.integer "household_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["household_id"], name: "index_users_on_household_id"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end

  create_table "weather_reports", force: :cascade do |t|
    t.integer "household_id", null: false
    t.integer "high", null: false
    t.integer "low", null: false
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.index ["household_id"], name: "index_weather_reports_on_household_id"
  end

  add_foreign_key "attendees", "events"
  add_foreign_key "attendees", "people"
  add_foreign_key "audit_entries", "households"
  add_foreign_key "calendar_source_people", "calendar_sources"
  add_foreign_key "calendar_source_people", "people"
  add_foreign_key "calendar_sources", "households"
  add_foreign_key "cameras", "households"
  add_foreign_key "catalog_items", "categories"
  add_foreign_key "catalog_items", "households"
  add_foreign_key "categories", "households"
  add_foreign_key "chore_completions", "chores"
  add_foreign_key "chore_completions", "people"
  add_foreign_key "chores", "households"
  add_foreign_key "chores", "people"
  add_foreign_key "chores", "routines"
  add_foreign_key "devices", "households"
  add_foreign_key "devices", "rooms"
  add_foreign_key "events", "calendar_sources"
  add_foreign_key "events", "households"
  add_foreign_key "grocery_items", "categories"
  add_foreign_key "grocery_items", "households"
  add_foreign_key "grocery_items", "stores"
  add_foreign_key "home_alerts", "cameras"
  add_foreign_key "home_alerts", "devices"
  add_foreign_key "home_alerts", "households"
  add_foreign_key "hourly_forecasts", "weather_reports"
  add_foreign_key "households", "scenes", column: "active_scene_id"
  add_foreign_key "media_players", "households"
  add_foreign_key "media_players", "rooms"
  add_foreign_key "people", "households"
  add_foreign_key "people", "users"
  add_foreign_key "photos", "households"
  add_foreign_key "photos", "people"
  add_foreign_key "rooms", "households"
  add_foreign_key "routines", "households"
  add_foreign_key "scene_activations", "households"
  add_foreign_key "scene_activations", "scenes"
  add_foreign_key "scene_settings", "devices"
  add_foreign_key "scene_settings", "scenes"
  add_foreign_key "scenes", "households"
  add_foreign_key "screens", "households"
  add_foreign_key "star_entries", "chore_completions"
  add_foreign_key "star_entries", "people"
  add_foreign_key "star_entries", "todos"
  add_foreign_key "store_categories", "categories"
  add_foreign_key "store_categories", "stores"
  add_foreign_key "stores", "households"
  add_foreign_key "thermostats", "households"
  add_foreign_key "todos", "households"
  add_foreign_key "todos", "people"
  add_foreign_key "todos", "people", column: "done_by_id"
  add_foreign_key "users", "households"
  add_foreign_key "users", "identities"
  add_foreign_key "weather_reports", "households"
end
