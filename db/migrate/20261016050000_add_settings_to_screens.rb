class AddSettingsToScreens < ActiveRecord::Migration[8.0]
  def change
    change_table :screens, bulk: true do |t|
      t.integer :night_from, null: false, default: 22
      t.integer :night_to, null: false, default: 6
      t.string :night_style, null: false, default: "off"
      t.string :default_view, null: false, default: "home"
      t.integer :reload_hour, default: 3
    end
  end
end
