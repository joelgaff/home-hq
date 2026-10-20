class AddActiveSceneToHouseholds < ActiveRecord::Migration[8.1]
  def change
    # The scene highlighted on Home control until a manual change (ui-spec §1.6).
    add_reference :households, :active_scene, foreign_key: { to_table: :scenes }
    # "Turn everything off" records a snapshot too, with no scene behind it.
    change_column_null :scene_activations, :scene_id, true
  end
end
