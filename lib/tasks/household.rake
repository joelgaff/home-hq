namespace :household do
  desc "From the demo data to the real household: clears the demo people and lists, keeps logins and screens, reseeds the catalogue"
  task fresh_start: :environment do
    household = Household.first or abort("no household yet")
    household.fresh_start!
    puts "Fresh start: #{household.name} has #{household.categories.count} categories and #{household.catalog_items.count} catalogue items; add people, routines, chores and stores in Settings."
  end

  desc "Removes the demo's home (rooms, devices, scenes, cameras, thermostat, speaker), photos and weather; keeps everything the household entered"
  task clear_samples: :environment do
    household = Household.first or abort("no household yet")
    household.clear_samples!
    puts "Samples cleared: #{household.devices.count} devices, #{household.photos.count} photos, #{household.weather_reports.count} weather reports left."
  end
end
