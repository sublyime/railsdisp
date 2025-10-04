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

      render_success("Weather data retrieved successfully", formatted_data)
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

      render_success("Weather data retrieved successfully", formatted_data)
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

      render_success("Current weather data retrieved successfully", formatted_data)
    rescue => e
      render_error("Failed to retrieve current weather data: #{e.message}")
    end
  end

  private

  def weather_params
    params.require(:weather).permit(:temperature, :wind_speed, :wind_direction, 
                                    :humidity, :pressure, :visibility, :latitude, 
                                    :longitude, :source)
  end
end