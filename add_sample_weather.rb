#!/usr/bin/env ruby

# Sample data seeder for weather testing
require_relative 'config/environment'

puts "🌤️  Adding sample weather data for testing..."

# Create sample weather data - All from weather.gov/NWS sources
sample_data = [
  {
    latitude: 40.7128,
    longitude: -74.0060,
    temperature: 22.5,
    wind_speed: 5.2,
    wind_direction: 180,
    humidity: 65,
    pressure: 1013.25,
    visibility: 10.0,
    source: 'weather.gov',
    recorded_at: Time.current
  },
  {
    latitude: 34.0522,
    longitude: -118.2437,
    temperature: 25.1,
    wind_speed: 3.8,
    wind_direction: 270,
    humidity: 58,
    pressure: 1015.8,
    visibility: 12.0,
    source: 'nws',
    recorded_at: Time.current - 1.hour
  },
  {
    latitude: 41.8781,
    longitude: -87.6298,
    temperature: 18.3,
    wind_speed: 7.1,
    wind_direction: 90,
    humidity: 72,
    pressure: 1011.2,
    visibility: 8.5,
    source: 'weather.gov',
    recorded_at: Time.current - 30.minutes
  }
]

begin
  sample_data.each do |data|
    weather = WeatherDatum.create!(data)
    puts "✅ Created weather data: #{weather.source} at #{weather.latitude}, #{weather.longitude}"
  end
  
  puts "\n📊 Weather data summary:"
  puts "Total records: #{WeatherDatum.count}"
  puts "Sources: #{WeatherDatum.distinct.pluck(:source).join(', ')}"
  puts "🎉 Sample data created successfully!"
  
rescue => e
  puts "❌ Error creating sample data: #{e.message}"
end