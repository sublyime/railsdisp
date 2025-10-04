class Api::V1::WeatherController < Api::V1::BaseController
  # GET /api/v1/weather
  def index
    begin
      # Get recent weather data from database
      weather_data = WeatherDatum.order(recorded_at: :desc).limit(50)

      formatted_data = weather_data.map do |data|
        {
          id: data.id,
          latitude: data.latitude,
          longitude: data.longitude,
          temperature: data.temperature,
          wind_speed: data.wind_speed,
          wind_direction: data.wind_direction,
          humidity: data.humidity,
          pressure: data.pressure,
          visibility: data.visibility,
          source: data.source,
          recorded_at: data.recorded_at,
          stability_class: data.stability_class,
          wind_vector: data.wind_vector,
          created_at: data.created_at
        }
      end

      render_success(formatted_data, "Weather data retrieved successfully")
    rescue => e
      render_error("Failed to retrieve weather data: #{e.message}")
    end
  end

  # GET /api/v1/weather/:id
  def show
    begin
      weather_data = WeatherDatum.find(params[:id])
      
      formatted_data = {
        id: weather_data.id,
        latitude: weather_data.latitude,
        longitude: weather_data.longitude,
        temperature: weather_data.temperature,
        wind_speed: weather_data.wind_speed,
        wind_direction: weather_data.wind_direction,
        humidity: weather_data.humidity,
        pressure: weather_data.pressure,
        visibility: weather_data.visibility,
        source: weather_data.source,
        recorded_at: weather_data.recorded_at,
        stability_class: weather_data.stability_class,
        wind_vector: weather_data.wind_vector,
        created_at: weather_data.created_at
      }

      render_success(formatted_data, "Weather data retrieved successfully")
    rescue ActiveRecord::RecordNotFound
      render_error("Weather data not found", 404)
    rescue => e
      render_error("Failed to retrieve weather data: #{e.message}")
    end
  end

  # GET /api/v1/weather/current
  def current
    begin
      # Get the most recent weather data for each unique location
      latest_weather = WeatherDatum.select("DISTINCT ON (latitude, longitude) *")
                                   .order(:latitude, :longitude, recorded_at: :desc)
                                   .limit(20)

      formatted_data = latest_weather.map do |data|
        {
          id: data.id,
          latitude: data.latitude,
          longitude: data.longitude,
          temperature: data.temperature,
          wind_speed: data.wind_speed,
          wind_direction: data.wind_direction,
          humidity: data.humidity,
          pressure: data.pressure,
          visibility: data.visibility,
          source: data.source,
          recorded_at: data.recorded_at,
          stability_class: data.stability_class,
          wind_vector: data.wind_vector,
          age_minutes: ((Time.current - data.recorded_at) / 60).round(1)
        }
      end

      render_success(formatted_data, "Current weather data retrieved successfully")
    rescue => e
      render_error("Failed to retrieve current weather data: #{e.message}")
    end
  end

  # GET /api/v1/weather/at_location?lat=xx&lng=xx
  def at_location
    begin
      lat = params[:lat].to_f
      lng = params[:lng].to_f
      
      if lat == 0.0 && lng == 0.0
        return render_error("Invalid coordinates provided", 400)
      end

      # Find nearest weather data within reasonable distance (100km)
      nearest_weather = WeatherDatum.select(
        "*, (6371 * acos(cos(radians(#{lat})) * cos(radians(latitude)) * cos(radians(longitude) - radians(#{lng})) + sin(radians(#{lat})) * sin(radians(latitude)))) AS distance"
      ).where(
        "recorded_at > ?", 24.hours.ago
      ).order(:distance).first

      if nearest_weather && nearest_weather.distance < 100 # within 100km
        formatted_data = {
          id: nearest_weather.id,
          latitude: nearest_weather.latitude,
          longitude: nearest_weather.longitude,
          temperature: nearest_weather.temperature,
          wind_speed: nearest_weather.wind_speed,
          wind_direction: nearest_weather.wind_direction,
          humidity: nearest_weather.humidity,
          pressure: nearest_weather.pressure,
          visibility: nearest_weather.visibility,
          source: nearest_weather.source,
          recorded_at: nearest_weather.recorded_at,
          stability_class: nearest_weather.stability_class,
          wind_vector: nearest_weather.wind_vector,
          distance_km: nearest_weather.distance.round(2),
          age_hours: ((Time.current - nearest_weather.recorded_at) / 3600).round(1)
        }

        render_success(formatted_data, "Weather data found for location")
      else
        # Generate mock weather data for the location if no real data available
        mock_weather = generate_mock_weather_data(lat, lng)
        render_success(mock_weather, "Mock weather data generated for location")
      end
    rescue => e
      render_error("Failed to retrieve weather for location: #{e.message}")
    end
  end

  private

  def weather_params
    params.require(:weather).permit(:temperature, :wind_speed, :wind_direction, 
                                    :humidity, :pressure, :visibility, :latitude, 
                                    :longitude, :source)
  end

  def generate_mock_weather_data(lat, lng)
    # Generate realistic mock weather data based on location and time
    current_time = Time.current
    hour = current_time.hour
    
    # Base temperature varies by time of day and latitude
    base_temp = 20 + (30 - lat.abs) * 0.5 # Warmer near equator
    daily_temp_variation = 8 * Math.sin((hour - 6) * Math::PI / 12) # Peak at 2pm
    temperature = (base_temp + daily_temp_variation + rand(-3..3)).round(1)
    
    {
      latitude: lat,
      longitude: lng,
      temperature: temperature,
      wind_speed: (2 + rand(0..10) + rand * 5).round(1),
      wind_direction: rand(0..359),
      humidity: rand(30..90),
      pressure: (1013.25 + rand(-15..15)).round(1),
      visibility: rand(5000..15000),
      source: "Generated",
      recorded_at: current_time,
      stability_class: ['A', 'B', 'C', 'D', 'E', 'F'].sample,
      wind_vector: nil,
      distance_km: 0,
      age_hours: 0,
      note: "Mock data generated for coordinates #{lat.round(4)}, #{lng.round(4)}"
    }
  end
end