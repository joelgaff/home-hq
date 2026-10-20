class AddWeekStartToHouseholds < ActiveRecord::Migration[8.0]
  def change
    # "monday" (Wes's month view) or "sunday"; the month grid and the chores week strip follow it.
    add_column :households, :week_start, :string, default: "monday", null: false
  end
end
