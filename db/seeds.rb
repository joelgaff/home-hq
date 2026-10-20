# Demo household built from Wes's prototype data (docs/ui-spec.md §2), relative to today so the
# demo always looks current. Idempotent: it fills the first household only while it has no people,
# so running it again (or on a household already set up) changes nothing. Real household data is
# entered through the app from milestone 3 on; nothing here is ours.

household = Household.first || Household.create!(name: "Demo household")
# A fresh demo household takes its time zone from the environment (HOME_DASHBOARD_TIME_ZONE); the
# demo day is built in that zone.
if household.people.none? && ENV["HOME_DASHBOARD_TIME_ZONE"].present?
  household.update!(time_zone: ENV["HOME_DASHBOARD_TIME_ZONE"])
end

if household.people.none?
  household.update!(demo: true)  # the demo tools (drawer, presets, tip) come with the demo data
  Time.use_zone(household.time_zone) do
    today = Time.zone.today
    at = ->(day, hm) { Time.zone.parse("#{today + day} #{hm}") }

    # ------------------------------------------------------------------ people
    people = {}
    [
      [ :wes, "Wes", "#2D5BFF", "#FFFFFF", false, false, "Driving home", 12 ],
      [ :claudia, "Claudia", "#E4007C", "#FFFFFF", false, false, "At the office", nil ],
      [ :buzzsaw, "Buzzsaw", "#00A36C", "#FFFFFF", true, true, "Home", nil ],
      [ :skidmark, "Skidmark", "#FFB000", "#111111", true, true, "Home", nil ]
    ].each_with_index do |(key, name, color, ink, kid, home, status, eta), i|
      people[key] = household.people.create!(name: name, color: color, ink: ink, kid: kid, home: home, status: status, eta_minutes: eta, position: i + 1)
    end
    all = people.keys

    # ------------------------------------------------------------------ calendar
    event = lambda do |day, from, to, title, who, loc: nil, travel: nil, notes: nil, demo: nil|
      e = household.events.create!(title: title, starts_at: at.(day, from), ends_at: at.(day, to), location: loc, travel_minutes: travel, notes: notes, demo_set: demo)
      who.each { |k| e.attendees.create!(person: people[k]) }
      e
    end
    all_day = lambda do |day, days, title, who, loc: nil|
      e = household.events.create!(title: title, all_day: true, starts_at: at.(day, "00:00"), ends_at: at.(day + days, "00:00"), location: loc)
      who.each { |k| e.attendees.create!(person: people[k]) }
      e
    end

    all_day.(0, 1, "Pajama Day at school", [ :skidmark ])
    all_day.(0, 1, "Garbage + recycling night", all)
    event.(0, "07:00", "07:45", "Gym", [ :claudia ], loc: "Iron Works")
    event.(0, "08:15", "08:40", "School drop-off", [ :wes ], travel: 10, loc: "Parkdale Elementary")
    event.(0, "09:30", "10:30", "Design review", [ :claudia ], loc: "Office · Room 4B")
    event.(0, "12:00", "12:45", "Dentist", [ :buzzsaw, :claudia ], travel: 15, loc: "Bright Smiles Dental")
    event.(0, "13:00", "14:00", "Lunch with Sam", [ :wes ], loc: "Café Rustica")
    event.(0, "15:45", "16:30", "Piano lesson", [ :skidmark ], travel: 12, loc: "Ms. Park's Studio", notes: "Bring the blue theory book.")
    event.(0, "16:05", "16:30", "Drive Buzzsaw to soccer", [ :claudia ])
    event.(0, "16:25", "16:50", "Pick up Skidmark", [ :claudia ], loc: "Ms. Park's Studio")
    event.(0, "16:30", "18:00", "Soccer practice", [ :buzzsaw ], travel: 20, loc: "Lakeshore Fields", notes: "Shin guards + water bottle. Rain likely — pack a jacket.")
    event.(0, "17:00", "17:30", "Parent–teacher call", [ :wes, :claudia ], loc: "Zoom")
    event.(0, "18:30", "19:30", "Dinner at Nonna's", all, travel: 20, loc: "Nonna's", notes: "Bring the lemon cake.")
    event.(0, "20:00", "20:30", "Bath + books", [ :skidmark ])

    all_day.(1, 3, "Wes in Montréal", [ :wes ], loc: "Hotel William Gray")
    event.(1, "07:00", "07:45", "Gym", [ :claudia ], loc: "Iron Works")
    event.(1, "08:15", "08:40", "School drop-off", [ :claudia ], travel: 10)
    event.(1, "10:30", "11:15", "Vet — Biscuit", [ :claudia ], travel: 10, loc: "Riverdale Animal Clinic")
    event.(1, "15:30", "16:30", "Art club", [ :buzzsaw ], loc: "School")
    event.(1, "16:00", "18:00", "Playdate with Leo", [ :skidmark ], travel: 8, loc: "Leo's house")
    event.(1, "19:00", "21:00", "Book club", [ :claudia ], travel: 10, loc: "Priya's")

    event.(2, "09:00", "14:00", "Science Centre trip", [ :skidmark ], loc: "Ontario Science Centre")
    event.(2, "13:00", "13:45", "Haircuts", [ :buzzsaw, :skidmark ], travel: 10, loc: "Snip Snip Kids")
    event.(2, "16:30", "18:00", "Soccer practice", [ :buzzsaw ], travel: 20, loc: "Lakeshore Fields")
    event.(2, "18:00", "19:30", "Pizza night", all)

    event.(3, "10:00", "10:45", "Swim lessons", [ :skidmark ], travel: 12, loc: "Wellesley Pool")
    event.(3, "11:00", "12:00", "Grocery run", [ :claudia ])
    event.(3, "13:00", "15:30", "Zoe's birthday party", [ :buzzsaw ], travel: 15, loc: "Pottery Place")
    event.(3, "19:00", "21:00", "Movie night", all)

    event.(4, "10:30", "12:00", "Sunday brunch", all, travel: 15, loc: "Lady Marmalade")
    event.(4, "17:05", "18:20", "Flight home · AC 418", [ :wes ], loc: "YUL → YYZ")

    event.(5, "07:00", "07:45", "Gym", [ :claudia ])
    event.(5, "15:45", "16:30", "Piano lesson", [ :skidmark ], travel: 12)
    event.(5, "16:30", "18:00", "Soccer practice", [ :buzzsaw ], travel: 20)
    event.(5, "19:00", "20:00", "Yoga", [ :claudia ])

    all_day.(6, 2, "Grandma visits", all)
    event.(6, "09:00", "09:45", "Dentist", [ :skidmark ], travel: 15, loc: "Bright Smiles Dental")
    event.(6, "16:30", "18:00", "Soccer practice", [ :buzzsaw ], travel: 20)

    # Background recurring events so the month view has texture.
    (-40..45).each do |d|
      next if (0..6).cover?(d)
      dow = (today + d).wday
      event.(d, "15:45", "16:30", "Piano lesson", [ :skidmark ]) if dow == 1
      event.(d, "16:30", "18:00", "Soccer practice", [ :buzzsaw ]) if dow == 2 || dow == 4
      event.(d, "19:00", "20:00", "Yoga", [ :claudia ]) if dow == 3
      event.(d, "10:00", "10:45", "Swim lessons", [ :skidmark ]) if dow == 6
      event.(d, "17:30", "19:30", "Dinner at Nonna's", all) if dow == 0
      event.(d, "18:00", "19:30", "Pizza night", all) if dow == 5 && d.even?
      event.(d, "12:00", "13:00", "Lunch meeting", [ :wes ]) if (d % 9).zero?
      event.(d, "09:00", "10:00", "Doctor", [ :claudia ]) if (d % 11).zero?
    end
    all_day.(12, 1, "Buzzsaw's birthday 🎂", all)
    all_day.(-8, 3, "Cottage weekend", all)

    # Extras for the demo drawer's "Overloaded" day.
    event.(0, "10:00", "11:00", "Plumber window", [ :claudia ], demo: "busy")
    event.(0, "11:00", "11:30", "Call with bank", [ :wes ], demo: "busy")
    event.(0, "14:30", "15:30", "Library volunteer", [ :claudia ], demo: "busy")
    event.(0, "15:30", "16:00", "Snack prep", [ :buzzsaw ], demo: "busy")
    event.(0, "16:00", "16:45", "Math tutor", [ :skidmark ], demo: "busy")
    event.(0, "16:15", "17:00", "Swim make-up", [ :skidmark ], travel: 10, demo: "busy")
    event.(0, "19:45", "20:30", "Bake sale prep", [ :buzzsaw, :claudia ], demo: "busy")
    event.(0, "20:30", "21:30", "Hockey", [ :wes ], travel: 15, demo: "busy")

    # ------------------------------------------------------------------ chores
    routines = {}
    [ [ :morning, "Morning", "6 – 11 AM", 0, 11 ], [ :after, "After school", "11 AM – 5 PM", 11, 17 ], [ :evening, "Evening", "5 – 10 PM", 17, 24 ] ].each_with_index do |(key, name, range, from, to), i|
      routines[key] = household.routines.create!(name: name, range_label: range, from_hour: from, to_hour: to, position: i + 1)
    end
    earned_today = Hash.new(0)
    chore = lambda do |routine, who, title, emoji, stars, done|
      c = household.chores.create!(routine: routines[routine], person: who && people[who], title: title, emoji: emoji, stars: stars, position: routines[routine].chores.count + 1)
      if done
        c.complete!
        earned_today[who] += stars if who && people[who].kid?
      end
      c
    end
    chore.(:morning, :buzzsaw, "Make bed", "🛏️", 1, true)
    chore.(:morning, :buzzsaw, "Brush teeth", "🪥", 1, true)
    chore.(:morning, :buzzsaw, "Pack backpack", "🎒", 1, true)
    chore.(:morning, :skidmark, "Make bed", "🛏️", 1, true)
    chore.(:morning, :skidmark, "Brush teeth", "🪥", 1, true)
    chore.(:morning, :skidmark, "Get dressed", "👕", 1, false)
    chore.(:morning, :wes, "School drop-off", "🚗", 0, true)
    chore.(:morning, :claudia, "Pack lunches", "🥪", 0, true)
    chore.(:morning, nil, "Feed Biscuit", "🐶", 1, true)
    chore.(:after, :buzzsaw, "Unpack lunchbox", "🥪", 1, true)
    chore.(:after, :buzzsaw, "Homework", "📚", 2, false)
    chore.(:after, :buzzsaw, "Pack soccer bag", "⚽", 1, false)
    chore.(:after, :skidmark, "Unpack lunchbox", "🥪", 1, true)
    chore.(:after, :skidmark, "Read for 20 min", "📖", 2, false)
    chore.(:after, :skidmark, "Practice piano", "🎹", 2, false)
    chore.(:after, :skidmark, "Tidy the Lego", "🧱", 1, false)
    # A morning chore left undone is "overdue" by the afternoon (plan: Gap review answers).
    chore.(:morning, :wes, "Take out recycling", "♻️", 0, false)
    chore.(:after, :wes, "Call the plumber", "☎️", 0, true)
    chore.(:after, :claudia, "Fold laundry", "🧺", 0, false)
    chore.(:after, :claudia, "Order Zoe’s gift", "🎁", 0, true)
    chore.(:after, nil, "Water the plants", "🪴", 1, false)
    chore.(:after, nil, "Empty dishwasher", "🍽️", 2, false)
    chore.(:after, nil, "Walk Biscuit", "🐕", 2, true)
    chore.(:evening, :buzzsaw, "Set the table", "🍴", 1, false)
    chore.(:evening, :buzzsaw, "Lay out clothes", "👕", 1, false)
    chore.(:evening, :buzzsaw, "Shower", "🚿", 1, false)
    chore.(:evening, :skidmark, "Clear plates", "🍽️", 1, false)
    chore.(:evening, :skidmark, "Bath", "🛁", 1, false)
    chore.(:evening, :skidmark, "Lay out clothes", "👕", 1, false)
    chore.(:evening, :wes, "Lock up", "🔐", 0, false)
    chore.(:evening, :claudia, "Run dishwasher", "🫧", 0, false)
    chore.(:evening, nil, "Wipe counters", "🧽", 1, false)
    chore.(:evening, nil, "Garbage to curb", "🗑️", 2, false)
    # Star totals as in the prototype (42 / 57), and this week's hit/miss history Mon..Sun.
    { buzzsaw: [ 42, [ 1, 1, 0, 1, 1, 0, 1 ] ], skidmark: [ 57, [ 1, 0, 1, 1, 1, 1, 0 ] ] }.each do |who, (total, week)|
      people[who].star_entries.create!(amount: total - earned_today[who], note: "Opening balance")
      monday = today.beginning_of_week(:monday)
      week.each_with_index do |hit, i|
        day = monday + i
        next unless day < today && hit == 1
        people[who].chores.each { |c| c.completions.create!(completed_on: day) }
      end
    end

    # ------------------------------------------------------------------ shopping
    stores = { grocer: household.stores.create!(name: "FreshCo", position: 1), costco: household.stores.create!(name: "Costco", position: 2) }
    cats = household.seed_catalog!
    [ "Household", "Pantry", "Snacks", "Dairy & Eggs", "Meat & Fish", "Frozen", "Produce", "Bakery" ].each_with_index do |name, i|
      stores[:costco].store_categories.create!(category: cats[name], position: i + 1)
    end
    [
      [ "Bananas", "Produce", 1, :grocer, false, "Bunch, not too ripe" ], [ "Baby spinach", "Produce", 1, :grocer ], [ "Avocados", "Produce", 3, :grocer ],
      [ "Honeycrisp apples", "Produce", 6, :grocer ], [ "Sourdough loaf", "Bakery", 1, :grocer ], [ "Bagels", "Bakery", 2, :costco, false, "Everything" ],
      [ "Chicken thighs", "Meat & Fish", 1, :grocer, false, "Boneless" ], [ "Salmon fillets", "Meat & Fish", 2, :grocer ], [ "Milk 2%", "Dairy & Eggs", 2, :costco ],
      [ "Eggs", "Dairy & Eggs", 1, :costco, false, "2 dozen" ], [ "Greek yogurt", "Dairy & Eggs", 1, :grocer ], [ "Aged cheddar", "Dairy & Eggs", 1, :grocer ],
      [ "Rigatoni", "Pantry", 2, :grocer ], [ "Olive oil", "Pantry", 1, :costco ], [ "Coffee beans", "Pantry", 1, :grocer, false, "Dark roast" ],
      [ "Frozen peas", "Frozen", 1, :grocer ], [ "Waffles", "Frozen", 1, :grocer ], [ "Goldfish crackers", "Snacks", 1, :costco ], [ "Granola bars", "Snacks", 1, :grocer ],
      [ "Paper towels", "Household", 1, :costco ], [ "Dish soap", "Household", 1, :grocer ], [ "Lemons", "Produce", 2, :grocer, true ],
      [ "Butter", "Dairy & Eggs", 1, :grocer, true ], [ "Tortillas", "Bakery", 1, :grocer, true ]
    ].each do |name, cat, qty, store, done = false, note = nil|
      household.grocery_items.create!(name: name, category: cats[cat], quantity: qty, store: stores[store], note: note, checked_at: done ? Time.current - 1.hour : nil)
    end

    # ------------------------------------------------------------------ home control
    rooms = {}
    [ [ :kitchen, "Kitchen" ], [ :living, "Living Room" ], [ :entry, "Entry + Garage" ], [ :upstairs, "Upstairs" ], [ :yard, "Backyard" ] ].each_with_index do |(key, name), i|
      rooms[key] = household.rooms.create!(name: name, position: i + 1)
    end
    devices = {}
    [
      [ "k-pend", :kitchen, Light, "Pendants", { on: true, level: 80 } ],
      [ "k-under", :kitchen, Light, "Under Cabinet", { on: true, level: 55 } ],
      [ "k-island", :kitchen, Light, "Island", { on: false, level: 100 } ],
      [ "k-shade", :kitchen, Blind, "Window Shade", { position: 100 } ],
      [ "l-lamp", :living, Light, "Floor Lamp", { on: true, level: 45 } ],
      [ "l-ceil", :living, Light, "Ceiling", { on: false, level: 100 } ],
      [ "l-blinds", :living, Blind, "Blinds", { position: 60 } ],
      [ "l-fire", :living, Light, "Mantel", { on: false, level: 70 } ],
      [ "e-door", :entry, DoorLock, "Front Door", { locked: true } ],
      [ "e-porch", :entry, Light, "Porch", { on: true, level: 100 } ],
      [ "g-door", :entry, GarageDoor, "Garage", { state: "closed" } ],
      [ "g-side", :entry, DoorLock, "Side Door", { locked: true } ],
      [ "u-maya", :upstairs, Light, "Buzzsaw's Lamp", { on: true, level: 30 } ],
      [ "u-otto", :upstairs, Light, "Skidmark's Nightlight", { on: false, level: 15 } ],
      [ "u-hall", :upstairs, Light, "Hallway", { on: false, level: 60 } ],
      [ "u-bath", :upstairs, Light, "Bathroom", { on: false, level: 100 } ],
      [ "y-string", :yard, Light, "String Lights", { on: false, level: 100 }, true ],
      [ "y-back", :yard, DoorLock, "Back Door", { locked: true } ],
      [ "y-flood", :yard, Light, "Floodlight", { on: false, level: 100 } ]
    ].each_with_index do |(key, room, type, name, state, flaky), i|
      devices[key] = household.devices.create!(room: rooms[room], name: name, position: i + 1, flaky: !!flaky, deviceable: type.create!(state))
    end
    [
      [ "Morning", "sunrise", false, { "k-pend" => 100, "k-under" => 80, "l-blinds" => 100, "l-lamp" => 0, "u-hall" => 60 } ],
      [ "Dinner", "utensils", false, { "k-pend" => 55, "k-under" => 30, "k-island" => 70, "l-lamp" => 40, "l-ceil" => 0 } ],
      [ "Movie", "film", false, { "k-pend" => 0, "k-under" => 15, "k-island" => 0, "l-lamp" => 15, "l-ceil" => 0, "l-blinds" => 0, "l-fire" => 30 } ],
      [ "Away", "away", true, { "k-pend" => 0, "k-under" => 0, "k-island" => 0, "l-lamp" => 0, "l-ceil" => 0, "l-fire" => 0, "u-maya" => 0, "u-hall" => 0, "e-porch" => 100 } ],
      [ "Goodnight", "moon", true, { "k-pend" => 0, "k-under" => 10, "k-island" => 0, "l-lamp" => 0, "l-ceil" => 0, "l-fire" => 0, "u-hall" => 10, "u-otto" => 15, "e-porch" => 0 } ]
    ].each_with_index do |(name, icon, locks_all, set), i|
      scene = household.scenes.create!(name: name, icon: icon, locks_all: locks_all, position: i + 1)
      set.each { |key, level| scene.scene_settings.create!(device: devices[key], level: level) }
    end
    household.create_thermostat!(current_temperature: 20.5, target_temperature: 21.5, mode: "heat", humidity: 42, outside_temperature: 14)
    household.create_media_player!(room: rooms[:kitchen], title: "Harvest Moon", artist: "Neil Young", playing: true, art_key: "harvest-vinyl")
    [ [ "Front Porch", "porch-steps" ], [ "Driveway", "driveway-maple" ], [ "Backyard", "garden-yard" ] ].each_with_index do |(name, key), i|
      household.cameras.create!(name: name, image_key: key, position: i + 1)
    end

    # ------------------------------------------------------------------ photos
    mmdd = today.strftime("%m-%d")
    [
      [ "tofino-surf", "l", "2021-#{mmdd}", "Tofino, BC", :claudia, "tofino" ], [ "cottage-dock", "l", "2023-08-12", "Lake of Bays", :wes, "cottage" ],
      [ "maya-kite", "p", "2024-05-19", "Humber Bay Park", :claudia, "spring24" ], [ "otto-kite", "p", "2024-05-19", "Humber Bay Park", :wes, "spring24" ],
      [ "autumn-walk", "l", "2022-10-09", "High Park", :wes, "fall22" ], [ "birthday-cake", "p", "2025-10-12", "Home", :claudia, "bday25" ],
      [ "candles-lit", "p", "2025-10-12", "Home", :wes, "bday25" ], [ "mountain-lake", "l", "2019-#{mmdd}", "Banff, AB", :wes, "banff" ],
      [ "snow-day", "l", "2024-01-21", "Riverdale Hill", :claudia, "winter24" ], [ "beach-dunes", "l", "2023-07-02", "Sandbanks", :buzzsaw, "sandbanks" ],
      [ "city-night", "l", "2022-12-18", "Nathan Phillips Sq.", :claudia, "xmas22" ], [ "garden-bloom", "p", "2025-06-08", "Backyard", :skidmark, "garden" ],
      [ "tomato-haul", "p", "2025-06-08", "Backyard", :buzzsaw, "garden" ], [ "road-trip", "l", "2024-08-04", "Cabot Trail, NS", :wes, "ns" ],
      [ "campfire", "l", "2024-08-06", "Cape Breton", :claudia, "ns" ], [ "forest-path", "l", "2020-09-26", "Algonquin", :wes, "algonquin" ],
      [ "pancakes", "p", "2026-03-14", "Home", :buzzsaw, "pancakes" ], [ "sugar-shack", "p", "2026-03-14", "Sugar Shack", :claudia, "pancakes" ],
      [ "harbour-sail", "l", "2025-07-19", "Toronto Harbour", :skidmark, "sail" ], [ "pumpkins", "l", "2025-10-25", "Chudleigh's", :buzzsaw, "fall25" ]
    ].each do |key, o, date, place, from, album|
      household.photos.create!(image_key: key, orientation: o == "p" ? "portrait" : "landscape", taken_on: Date.parse(date), place: place, person: people[from], album: album)
    end

    # ------------------------------------------------------------------ weather (index = hour)
    report = household.weather_reports.create!(high: 17, low: 8, fetched_at: Time.current)
    temps = [ 9, 9, 8, 8, 8, 8, 9, 10, 11, 12, 13, 15, 16, 17, 16, 15, 14, 13, 12, 12, 11, 10, 10, 9 ]
    conds = %w[moon moon moon moon moon moon partly partly sun sun sun partly partly cloud cloud cloud rain rain rain rain cloud cloud moon moon]
    rain = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 10, 20, 25, 40, 80, 90, 70, 55, 20, 10, 0, 0 ]
    24.times { |h| report.hourly_forecasts.create!(hour: h, temperature: temps[h], condition: conds[h], precipitation_chance: rain[h]) }
  end
end
