# The outdoor words that turn "Grab a rain jacket" into "Pack a rain jacket for soccer" (plan:
# Open-source readiness: rules as data, not code).
class AddRainKeywordsToHouseholds < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :rain_keywords, :string, null: false, default: "soccer, practice, game, hike, park"
  end
end
