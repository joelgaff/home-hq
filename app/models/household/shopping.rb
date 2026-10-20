# The shared shopping list's rules (ui-spec §1.4): grouping in a store's aisle order, catalogue
# categorisation, add/bump/revive, suggestions, usuals, and clearing the "Got it" drawer.
module Household::Shopping
  extend ActiveSupport::Concern

  included do
    has_many :stores, -> { in_order }, dependent: :destroy
    has_many :categories, -> { in_order }, dependent: :destroy
    has_many :catalog_items, -> { in_order }, dependent: :destroy
    has_many :grocery_items, dependent: :destroy
  end

  # [[category_name, [items]], ...] for the open items, in the store's aisle order (the household
  # order for "All"), "Other" last, empty categories skipped.
  def shopping_groups(store: nil)
    items = grocery_items.open.includes(:category, :store).in_order
    items = items.where(store: store) if store
    order = (store ? store.aisle_order : categories.in_order.to_a).map(&:name) + [ "Other" ]
    by_category = items.group_by(&:category_name)
    order.filter_map { |name| [ name, by_category[name] ] if by_category[name] }
  end

  # Catalogue lookup: exact name, then a substring either way, then any word over three letters.
  def categorize(name)
    n = name.downcase.strip
    items = catalog_items.includes(:category).to_a
    hit = items.find { |c| c.name.downcase == n } ||
      items.find { |c| (a = c.name.downcase).include?(n) || n.include?(a) } ||
      items.find { |c| n.split(/\s+/).any? { |w| w.length > 3 && c.name.downcase.include?(w) } }
    hit&.category
  end

  # Returns [:bumped | :revived | :added, item]. Adding from a store's tab files the item there,
  # even when it was already on the list or checked off.
  def add_grocery(name, store: nil)
    name = name.strip
    if (item = grocery_items.open.named(name).first)
      item.adjust_quantity!(1)
      item.update!(store: store) if store
      [ :bumped, item ]
    elsif (item = grocery_items.checked.named(name).first)
      item.revive!
      item.update!(store: store) if store
      [ :revived, item ]
    else
      catalog = catalog_items.find_by("LOWER(name) = ?", name.downcase)
      item = grocery_items.create!(name: catalog&.name || name.sub(/\A./, &:upcase), category: categorize(name),
        store: store || stores.first, quantity: 1)
      [ :added, item ]
    end
  end

  # Catalogue matches while typing: names starting with the query first, then containing it.
  def suggest(query, limit: 5)
    q = query.downcase.strip
    return [] if q.empty?
    items = catalog_items.includes(:category).to_a
    starts = items.select { |c| c.name.downcase.start_with?(q) }
    inside = items.select { |c| (i = c.name.downcase.index(q)) && i > 0 }
    (starts + inside).first(limit)
  end

  def usuals
    catalog_items.usual.includes(:category)
  end

  def clear_checked!
    items = grocery_items.checked.to_a
    grocery_items.where(id: items.map(&:id)).update_all(cleared_at: Current.now)
    items
  end

  def restore_cleared!(ids)
    grocery_items.where(id: ids).update_all(cleared_at: nil)
  end

  # The generic categories and catalogue every household starts from (plan: "seed common grocery
  # catalogue items and categories"); the demo seeds and the fresh start both use it. Adds what is
  # missing, never duplicates.
  CATEGORIES = [ "Produce", "Bakery", "Meat & Fish", "Dairy & Eggs", "Pantry", "Frozen", "Snacks", "Household" ].freeze
  CATALOG = {
    "Produce" => [ "Apples", "Avocados", "Bananas", "Baby spinach", "Blueberries", "Broccoli", "Carrots", "Cucumber", "Garlic", "Grapes", "Lemons", "Limes", "Onions", "Potatoes", "Strawberries", "Tomatoes" ],
    "Bakery" => [ "Bread", "Bagels", "Croissants", "Sourdough loaf", "Tortillas", "Hamburger buns" ],
    "Meat & Fish" => [ "Bacon", "Chicken breasts", "Chicken thighs", "Ground beef", "Salmon fillets", "Shrimp" ],
    "Dairy & Eggs" => [ "Butter", "Cheddar", "Cream cheese", "Eggs", "Greek yogurt", "Milk 2%", "Oat milk", "Parmesan" ],
    "Pantry" => [ "Black beans", "Cereal", "Coffee beans", "Flour", "Honey", "Maple syrup", "Olive oil", "Pasta sauce", "Peanut butter", "Rice", "Rigatoni", "Spaghetti", "Sugar", "Tea" ],
    "Frozen" => [ "Frozen peas", "Frozen berries", "Ice cream", "Pizza", "Waffles" ],
    "Snacks" => [ "Chips", "Crackers", "Dark chocolate", "Goldfish crackers", "Granola bars", "Popcorn" ],
    "Household" => [ "Dish soap", "Dishwasher pods", "Garbage bags", "Laundry detergent", "Paper towels", "Toilet paper", "Toothpaste" ]
  }.freeze
  USUALS = [ "Milk 2%", "Eggs", "Bananas", "Bread", "Apples", "Coffee beans", "Greek yogurt", "Cheddar", "Butter", "Baby spinach", "Chicken thighs", "Paper towels" ].freeze

  def seed_catalog!
    transaction do
      cats = CATEGORIES.each_with_index.to_h { |name, i| [ name, categories.find_or_create_by!(name: name) { |c| c.position = i + 1 } ] }
      n = catalog_items.count
      CATALOG.each do |cat, names|
        names.each do |name|
          next if catalog_items.exists?(name: name)
          catalog_items.create!(name: name, category: cats[cat], usual: USUALS.include?(name), position: USUALS.index(name) || (n += 1) + 100)
        end
      end
      cats
    end
  end
end
