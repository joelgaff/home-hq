class AddSchedulesToChores < ActiveRecord::Migration[8.1]
  def change
    # Chore schedules (plan: Gap review answers): daily, or specific weekdays, as a bitmask
    # (Mon = 1 ... Sun = 64; nil = every day). Routines take the same, for weekend-only ones.
    add_column :chores, :weekdays, :integer
    add_column :routines, :weekdays, :integer
    # The vacation pause: no chores are due until this date (inclusive).
    add_column :households, :chores_paused_until, :date
    # "Overdue" is now computed: due earlier today, not done.
    remove_column :chores, :overdue, :boolean, default: false, null: false
  end
end
