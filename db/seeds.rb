puts "Seeding database..."
Item.find_or_create_by!(name: "Example Item") do |item|
  item.description = "Created by db:seed to verify the setup works"
end
puts "Done! #{Item.count} item(s) in database."
