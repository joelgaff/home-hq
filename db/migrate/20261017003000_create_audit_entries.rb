class CreateAuditEntries < ActiveRecord::Migration[8.0]
  def change
    # The audit log (plan: second gap review): who did what, when. Names are copied so a removed
    # person or device still reads; details carry the changed attributes.
    create_table :audit_entries do |t|
      t.references :household, null: false, foreign_key: true
      t.string :action, null: false
      t.references :actor, polymorphic: true
      t.string :actor_name
      t.references :subject, polymorphic: true
      t.string :subject_name
      t.json :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_entries, %i[household_id created_at]
  end
end
