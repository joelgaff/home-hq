class AddTravelCheckedAtToEvents < ActiveRecord::Migration[8.0]
  def change
    # When the drive time was last asked of Home Assistant (plan: travel-time refresh rules).
    add_column :events, :travel_checked_at, :datetime
  end
end
