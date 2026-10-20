class CreateBlinds < ActiveRecord::Migration[8.1]
  def change
    create_table :blinds do |t|
      t.integer :position, null: false, default: 100

      t.timestamps
    end
  end
end
