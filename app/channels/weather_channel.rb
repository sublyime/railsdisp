# Weather Channel for real-time weather updates via WebSocket

class WeatherChannel < ApplicationCable::Channel
  def subscribed
    stream_from "weather_channel"
    
    # Send current weather data immediately upon subscription
    transmit_current_weather_data
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "Client unsubscribed from weather channel"
  end

  # Client can request weather update for specific location
  def request_weather_update(data)
    location_id = data['location_id']
    
    if location_id.present?
      WeatherUpdateJob.perform_later(location_id)
      transmit({
        message: "Weather update requested for location #{location_id}",
        status: 'queued'
      })
    else
      transmit({
        error: "Location ID required for weather update",
        status: 'error'
      })
    end
  end

  # Client can subscribe to specific location weather updates
  def subscribe_to_location(data)
    location_id = data['location_id']
    
    if location_id.present?
      stream_from "weather_location_#{location_id}"
      
      # Send current weather for this location
      location = Location.find_by(id: location_id)
      if location
        recent_weather = WeatherDatum.by_location(location.latitude, location.longitude)
                                     .recent
                                     .order(:recorded_at)
                                     .last
        
        if recent_weather
          transmit({
            location_id: location_id,
            weather_data: recent_weather.as_json,
            stability_class: recent_weather.stability_class,
            wind_vector: recent_weather.wind_vector
          })
        end
      end
    end
  end

  # Client can unsubscribe from specific location
  def unsubscribe_from_location(data)
    location_id = data['location_id']
    stop_stream_from "weather_location_#{location_id}" if location_id.present?
  end

  private

  def transmit_current_weather_data
    # Send recent weather data for all monitored locations
    Location.includes(:weather_data).find_each do |location|
      recent_weather = location.weather_data.recent.order(:recorded_at).last
      
      if recent_weather
        transmit({
          location_id: location.id,
          location_name: location.name,
          weather_data: recent_weather.as_json,
          stability_class: recent_weather.stability_class,
          wind_vector: recent_weather.wind_vector,
          coordinates: [location.latitude, location.longitude]
        })
      end
    end
  end
end