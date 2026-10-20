class AddUserToPeople < ActiveRecord::Migration[8.1]
  def change
    # The login a person uses on a phone (adults; nil for kids). Set in settings later.
    add_reference :people, :user, null: true, foreign_key: true
  end
end
