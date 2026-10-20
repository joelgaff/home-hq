class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.string :email
      t.string :login_code_digest
      t.datetime :login_code_expires_at

      t.timestamps
    end
    add_index :identities, :email, unique: true
  end
end
