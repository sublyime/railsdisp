# Background job for updating weather data
# Runs every 30 seconds to fetch current weather conditions
# for all monitored locations

require 'net/http'

class WeatherUpdateJob < ApplicationJob
  queue_as :weather_updates

  # Retry with exponential backoff for transient failures
  retry_on Net::ReadTimeout, Net::OpenTimeout, wait: :exponentially_longer, attempts: 3
  retry_on WeatherProviders::OpenWeatherMapService::APIError, wait: 5.minutes, attempts: 2

  def perform(location_id = nil)
    if location_id
      update_location_weather(location_id)
    else
      update_all_locations_weather
    end
  end

  private

  def update_location_weather(location_id)
    location = Location.find(location_id)
    
    Rails.logger.info "Updating weather for location: #{location.name}"
    
    begin
      weather_data = WeatherService.fetch_weather_data(location.latitude, location.longitude)
      create_weather_record(weather_data, location)
      
      # Update any active dispersion events at this location
      update_active_dispersions(location)
      
      Rails.logger.info "Successfully updated weather for #{location.name}"
    rescue => e
      Rails.logger.error "Failed to update weather for #{location.name}: #{e.message}"
      raise e
    end
  end

  def update_all_locations_weather
    Rails.logger.info "Starting weather update for all locations"
    
    locations_count = Location.count
    success_count = 0
    failure_count = 0
    
    Location.find_each do |location|
      begin
        weather_data = WeatherService.fetch_weather_data(location.latitude, location.longitude)
        create_weather_record(weather_data, location)
        update_active_dispersions(location)
        success_count += 1
      rescue => e
        Rails.logger.error "Failed to update weather for #{location.name}: #{e.message}"
        failure_count += 1
      end
    end
    
    Rails.logger.info "Weather update completed: #{success_count} successful, #{failure_count} failed out of #{locations_count} locations"
  end

  def create_weather_record(weather_data, location)
    # Only create new record if significantly different from last reading
    last_reading = WeatherDatum.where(
      latitude: location.latitude,
      longitude: location.longitude
    ).order(:recorded_at).last
    
    if should_create_record?(weather_data, last_reading)
      weather_record = WeatherDatum.create!(
        recorded_at: weather_data[:timestamp] || Time.current,
        temperature: weather_data[:temperature],
        humidity: weather_data[:humidity],
        pressure: weather_data[:pressure],
        wind_speed: weather_data[:wind_speed],
        wind_direction: weather_data[:wind_direction],
        precipitation: weather_data[:precipitation] || 0,
        cloud_cover: weather_data[:cloud_cover] || 0,
        visibility: weather_data[:visibility] || 10,
        latitude: location.latitude,
        longitude: location.longitude,
        source: weather_data[:source] || 'api'
      )
      
      # Calculate atmospheric stability for dispersion modeling
      stability_class = WeatherService.calculate_stability_class(weather_data)
      weather_record.update(atmospheric_stability: stability_class)
      
      # Broadcast weather update via WebSocket
      ActionCable.server.broadcast(
        "weather_channel",
        {
          location_id: location.id,
          weather_data: weather_record.as_json,
          stability_class: stability_class
        }
      )
    end
  end

  def should_create_record?(new_data, last_reading)
    return true unless last_reading
    
    # Create new record if:
    # 1. Last reading is older than 5 minutes
    # 2. Temperature changed by more than 1°C
    # 3. Wind speed changed by more than 2 m/s
    # 4. Wind direction changed by more than 15°
    
    time_threshold = 5.minutes.ago
    return true if last_reading.recorded_at < time_threshold
    
    temp_change = (new_data[:temperature] - last_reading.temperature).abs > 1.0
    wind_speed_change = (new_data[:wind_speed] - last_reading.wind_speed).abs > 2.0
    wind_dir_change = calculate_wind_direction_change(
      new_data[:wind_direction], 
      last_reading.wind_direction
    ) > 15.0
    
    temp_change || wind_speed_change || wind_dir_change
  end

  def calculate_wind_direction_change(new_dir, old_dir)
    diff = (new_dir - old_dir).abs
    [diff, 360 - diff].min # Account for circular nature of wind direction
  end

  def update_active_dispersions(location)
    # Find active dispersion events at this location
    active_events = DispersionEvent.joins(:location)
                                   .where(location: location)
                                   .where(status: ['active', 'monitoring'])
    
    active_events.find_each do |event|
      # Trigger recalculation of dispersion with new weather data
      DispersionCalculationJob.perform_later(event.id)
    end
  end
end