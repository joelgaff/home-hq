class AddEmailToPeople < ActiveRecord::Migration[8.0]
  def change
    # A member's email is their login (plan: Decisions, sign-in). Kids may have none.
    add_column :people, :email, :string
    add_index :people, [ :household_id, :email ], unique: true
  end
end
