# Base Weather Service
# Provides common functionality for weather data fetching and processing

class WeatherService
  class << self
    # Fetch weather data for a specific location
    def fetch_weather_data(latitude, longitude)
      provider = determine_best_provider(latitude, longitude)
      provider.fetch_current_weather(latitude, longitude)
    end

    # Fetch forecast data for dispersion planning
    def fetch_forecast_data(latitude, longitude, hours = 24)
      provider = determine_best_provider(latitude, longitude)
      provider.fetch_forecast(latitude, longitude, hours)
    end

    # Update weather data for all monitored locations
    def update_all_locations
      Location.all.find_each do |location|
        begin
          weather_data = fetch_weather_data(location.latitude, location.longitude)
          create_weather_record(weather_data, location)
        rescue => e
          Rails.logger.error "Failed to update weather for location #{location.name}: #{e.message}"
        end
      end
    end

    # Calculate atmospheric stability class from weather data
    def calculate_stability_class(weather_data)
      wind_speed = weather_data[:wind_speed]
      cloud_cover = weather_data[:cloud_cover] || 50
      time_of_day = weather_data[:timestamp] || Time.current
      
      # Pasquill-Gifford stability classification
      is_day = time_of_day.hour.between?(6, 18)
      
      if is_day
        # Daytime conditions based on solar radiation (approximated by cloud cover)
        if wind_speed < 2
          cloud_cover < 50 ? 'A' : 'D'
        elsif wind_speed < 3
          cloud_cover < 50 ? 'B' : 'D'
        elsif wind_speed < 5
          cloud_cover < 50 ? 'C' : 'D'
        else
          'D'
        end
      else
        # Nighttime conditions based on cloud cover
        if wind_speed < 2
          cloud_cover > 50 ? 'E' : 'F'
        elsif wind_speed < 3
          cloud_cover > 50 ? 'D' : 'E'
        else
          'D'
        end
      end
    end

    private

    def determine_best_provider(latitude, longitude)
      # For now, use OpenWeatherMap as primary provider
      # In production, you might have failover logic
      WeatherProviders::OpenWeatherMapService
    end

    def create_weather_record(weather_data, location)
      WeatherDatum.create!(
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
    end
  end
end