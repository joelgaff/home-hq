class CreateGarageDoors < ActiveRecord::Migration[8.1]
  def change
    create_table :garage_doors do |t|
      t.string :state, null: false, default: "closed"

      t.timestamps
    end
  end
end
