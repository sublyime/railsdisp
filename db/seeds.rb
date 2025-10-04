# Chemical Dispersion Modeling Application - Seed Data

puts "Creating seed data for Chemical Dispersion Modeling..."

# Sample Chemicals
puts "Creating chemicals..."

chemicals = [
  {
    name: "Chlorine",
    cas_number: "7782-50-5",
    molecular_weight: 70.9,
    boiling_point: -34.0,
    vapor_pressure: 6800.0,
    state: "gas",
    density: 3.21,
    hazard_class: "toxic_gas",
    description: "Highly toxic gas used in water treatment and chemical processes. Yellow-green gas with pungent odor."
  },
  {
    name: "Ammonia",
    cas_number: "7664-41-7",
    molecular_weight: 17.0,
    boiling_point: -33.3,
    vapor_pressure: 8600.0,
    state: "gas",
    density: 0.77,
    hazard_class: "toxic_gas",
    description: "Colorless gas with sharp odor. Used in fertilizers and cleaning products."
  },
  {
    name: "Sulfur Dioxide",
    cas_number: "7446-09-5",
    molecular_weight: 64.1,
    boiling_point: -10.0,
    vapor_pressure: 3300.0,
    state: "gas",
    density: 2.93,
    hazard_class: "toxic_gas",
    description: "Colorless gas with pungent odor. Used in paper production and as preservative."
  },
  {
    name: "Benzene",
    cas_number: "71-43-2",
    molecular_weight: 78.1,
    boiling_point: 80.1,
    vapor_pressure: 100.0,
    state: "liquid",
    density: 0.88,
    hazard_class: "carcinogen",
    description: "Colorless liquid with sweet odor. Used in plastics and chemical production."
  },
  {
    name: "Hydrogen Sulfide",
    cas_number: "7783-06-4",
    molecular_weight: 34.1,
    boiling_point: -60.0,
    vapor_pressure: 20270.0,
    state: "gas",
    density: 1.54,
    hazard_class: "toxic_gas",
    description: "Colorless gas with rotten egg odor. Highly toxic and flammable."
  }
]

chemicals.each do |chem_data|
  chemical = Chemical.find_or_create_by(cas_number: chem_data[:cas_number]) do |c|
    c.assign_attributes(chem_data)
  end
  puts "✓ Created/found chemical: #{chemical.name}"
end

# Sample Locations
puts "\nCreating locations..."

locations = [
  {
    name: "Industrial Complex A",
    latitude: 29.7604,
    longitude: -95.3698,
    elevation: 15.0,
    terrain_type: "urban",
    building_height: 25.0,
    description: "Major petrochemical facility with multiple process units"
  },
  {
    name: "Chemical Plant B",
    latitude: 29.7204,
    longitude: -95.4098,
    elevation: 8.0,
    terrain_type: "industrial",
    building_height: 40.0,
    description: "Large-scale chemical manufacturing plant"
  },
  {
    name: "Storage Terminal C",
    latitude: 29.8004,
    longitude: -95.3298,
    elevation: 12.0,
    terrain_type: "flat",
    building_height: 15.0,
    description: "Chemical storage and distribution facility"
  },
  {
    name: "Refinery D",
    latitude: 29.6804,
    longitude: -95.4398,
    elevation: 5.0,
    terrain_type: "coastal",
    building_height: 60.0,
    description: "Oil refinery with processing towers"
  },
  {
    name: "Research Facility E",
    latitude: 29.7404,
    longitude: -95.2898,
    elevation: 20.0,
    terrain_type: "suburban",
    building_height: 10.0,
    description: "Chemical research and development laboratory"
  }
]

locations.each do |loc_data|
  location = Location.find_or_create_by(name: loc_data[:name]) do |l|
    l.assign_attributes(loc_data)
  end
  puts "✓ Created/found location: #{location.name}"
end

# Sample Weather Data
puts "\nCreating weather data..."

# Create weather data for the past 24 hours
24.times do |hour|
  recorded_time = hour.hours.ago
  
  weather = WeatherDatum.find_or_create_by(recorded_at: recorded_time.beginning_of_hour) do |w|
    w.wind_speed = 2.0 + rand(8.0)  # 2-10 m/s
    w.wind_direction = rand(360)     # 0-359 degrees
    w.temperature = 15.0 + rand(20.0) # 15-35°C
    w.humidity = 30.0 + rand(50.0)   # 30-80%
    w.pressure = 1000.0 + rand(50.0) # 1000-1050 hPa
    w.precipitation = rand < 0.1 ? rand(5.0) : 0 # 10% chance of rain
    w.cloud_cover = rand(100.0)      # 0-100%
    w.visibility = 5.0 + rand(15.0)  # 5-20 km
    w.latitude = 29.7604             # Houston area
    w.longitude = -95.3698
    w.source = "automated_station"
  end
end

puts "✓ Created 24 hours of weather data"

# Sample Dispersion Events
puts "\nCreating sample dispersion events..."

# Get our created chemicals and locations
chlorine = Chemical.find_by(name: "Chlorine")
ammonia = Chemical.find_by(name: "Ammonia")
benzene = Chemical.find_by(name: "Benzene")

plant_a = Location.find_by(name: "Industrial Complex A")
plant_b = Location.find_by(name: "Chemical Plant B")
storage_c = Location.find_by(name: "Storage Terminal C")

# Verify all chemicals and locations were found
puts "Found chemicals: #{[chlorine, ammonia, benzene].compact.map(&:name).join(', ')}"
puts "Found locations: #{[plant_a, plant_b, storage_c].compact.map(&:name).join(', ')}"

# Only proceed if all required records exist
if chlorine && ammonia && benzene && plant_a && plant_b

events = [
  {
    chemical: chlorine,
    location: plant_a,
    release_rate: 0.5,
    release_duration: 3600,
    release_volume: 1800.0,
    release_mass: 500.0,
    release_type: "continuous",
    started_at: 2.hours.ago,
    ended_at: 1.hour.ago,
    status: "completed",
    notes: "Minor chlorine leak from process line"
  },
  {
    chemical: ammonia,
    location: plant_b,
    release_rate: 2.0,
    release_duration: 1800,
    release_volume: 3600.0,
    release_mass: 1200.0,
    release_type: "continuous",
    started_at: 30.minutes.ago,
    ended_at: nil,
    status: "active",
    notes: "Ongoing ammonia release from storage tank vent"
  },
  {
    chemical: benzene,
    location: plant_a,  # Use plant_a instead of missing storage_c
    release_rate: 0.1,
    release_duration: 7200,
    release_volume: 720.0,
    release_mass: 100.0,
    release_type: "continuous",
    started_at: 6.hours.ago,
    ended_at: 4.hours.ago,
    status: "completed",
    notes: "Benzene vapor release during tank loading"
  }
]

events.each_with_index do |event_data, index|
  chemical = event_data.delete(:chemical)
  location = event_data.delete(:location)
  
  event = DispersionEvent.find_or_create_by(
    chemical: chemical,
    location: location,
    started_at: event_data[:started_at]
  ) do |e|
    e.assign_attributes(event_data)
  end
  
  # Ensure the event is saved
  unless event.persisted?
    puts "❌ Failed to create event: #{event.errors.full_messages.join(', ')}"
    next
  end
  
  puts "✓ Created/found dispersion event: #{chemical.name} at #{location.name}"
  
  # Create some sample receptors for each event
  if event.receptors.empty?
    5.times do |i|
      angle = i * 72  # 72 degrees apart (360/5)
      distance = 500 + rand(1500)  # 500-2000 meters
      
      # Calculate lat/lng offset
      lat_offset = (distance * Math.cos(angle * Math::PI / 180)) / 111320.0
      lng_offset = (distance * Math.sin(angle * Math::PI / 180)) / (111320.0 * Math.cos(location.latitude * Math::PI / 180))
      
      receptor = event.receptors.create!(
        name: "Receptor #{i+1}",
        latitude: location.latitude + lat_offset,
        longitude: location.longitude + lng_offset,
        distance_from_source: distance,
        notes: "Monitoring point #{distance}m #{angle}° from source"
      )
    end
    puts "  ✓ Created 5 receptors for #{chemical.name} event"
  end
end

else
  puts "❌ Error: Some required chemicals or locations were not found!"
  puts "Missing chemicals: #{[chlorine, ammonia, benzene].select(&:nil?).count}"
  puts "Missing locations: #{[plant_a, plant_b, storage_c].select(&:nil?).count}"
end

puts "\n🎉 Seed data creation completed!"
puts "📊 Summary:"
puts "  - #{Chemical.count} chemicals"
puts "  - #{Location.count} locations"
puts "  - #{WeatherDatum.count} weather records"
puts "  - #{DispersionEvent.count} dispersion events"
puts "  - #{Receptor.count} receptors"
puts "  - #{DispersionCalculation.count} calculations"

puts "\n🌐 Visit http://localhost:3000 to view the application!"
