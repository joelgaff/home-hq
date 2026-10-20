class AddPinDigestToPeople < ActiveRecord::Migration[8.0]
  def change
    # An adult's PIN for unlocking from the frame (plan: gap review), bcrypt digest.
    add_column :people, :pin_digest, :string
  end
end
