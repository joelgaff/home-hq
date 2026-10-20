class CreateHomeAlerts < ActiveRecord::Migration[8.0]
  def change
    # Alerts from the house (plan: milestone 6): doorbell, package, leak, garage left open. Kept so
    # the frame can acknowledge them and the log can say who did.
    create_table :home_alerts do |t|
      t.references :household, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :message
      t.references :camera, foreign_key: true
      t.references :device, foreign_key: true
      t.json :details, null: false, default: {}
      t.datetime :acknowledged_at
      t.string :acknowledged_by
      t.timestamps
    end
    add_index :home_alerts, %i[household_id created_at]
  end
end
