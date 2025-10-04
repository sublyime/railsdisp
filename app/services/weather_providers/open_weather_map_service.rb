# OpenWeatherMap API Service
# Handles all interactions with OpenWeatherMap API
# Requires API key configuration in Rails credentials

require 'net/http'
require 'json'
require 'timeout'

module WeatherProviders
  class OpenWeatherMapService
    BASE_URL = 'https://api.openweathermap.org/data/2.5'
    
    class << self
      # Fetch current weather data
      def fetch_current_weather(latitude, longitude)
        url = "#{BASE_URL}/weather?lat=#{latitude}&lon=#{longitude}&appid=#{api_key}&units=metric"
        response = make_request(url)
        parse_current_weather_response(response)
      end

      # Fetch weather forecast
      def fetch_forecast(latitude, longitude, hours = 24)
        url = "#{BASE_URL}/forecast?lat=#{latitude}&lon=#{longitude}&appid=#{api_key}&units=metric"
        response = make_request(url)
        parse_forecast_response(response, hours)
      end

      # Fetch historical weather data
      def fetch_historical_weather(latitude, longitude, timestamp)
        url = "#{BASE_URL}/onecall/timemachine?lat=#{latitude}&lon=#{longitude}&dt=#{timestamp}&appid=#{api_key}&units=metric"
        response = make_request(url)
        parse_historical_response(response)
      end

      private

      def api_key
        Rails.application.credentials.dig(:openweathermap, :api_key) ||
        ENV['OPENWEATHERMAP_API_KEY'] ||
        raise(ConfigurationError, "OpenWeatherMap API key not configured")
      end

      def make_request(url)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10
        http.open_timeout = 5

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        unless response.code.to_i == 200
          raise APIError, "OpenWeatherMap API error: #{response.code} - #{response.body}"
        end

        JSON.parse(response.body)
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        raise APIError, "OpenWeatherMap API timeout: #{e.message}"
      rescue JSON::ParserError => e
        raise APIError, "Invalid JSON response from OpenWeatherMap: #{e.message}"
      end

      def parse_current_weather_response(data)
        {
          timestamp: Time.at(data['dt']),
          temperature: data['main']['temp'],
          humidity: data['main']['humidity'],
          pressure: data['main']['pressure'],
          wind_speed: data['wind']['speed'],
          wind_direction: data['wind']['deg'],
          precipitation: extract_precipitation(data),
          cloud_cover: data['clouds']['all'],
          visibility: (data['visibility'] || 10000) / 1000.0, # Convert to km
          weather_description: data['weather'][0]['description'],
          source: 'openweathermap'
        }
      end

      def parse_forecast_response(data, hours)
        forecasts = data['list'].first(hours / 3) # API returns 3-hour intervals
        
        forecasts.map do |forecast|
          {
            timestamp: Time.at(forecast['dt']),
            temperature: forecast['main']['temp'],
            humidity: forecast['main']['humidity'],
            pressure: forecast['main']['pressure'],
            wind_speed: forecast['wind']['speed'],
            wind_direction: forecast['wind']['deg'],
            precipitation: extract_precipitation(forecast),
            cloud_cover: forecast['clouds']['all'],
            visibility: 10.0, # Default for forecast data
            weather_description: forecast['weather'][0]['description'],
            source: 'openweathermap_forecast'
          }
        end
      end

      def parse_historical_response(data)
        current = data['current']
        {
          timestamp: Time.at(current['dt']),
          temperature: current['temp'],
          humidity: current['humidity'],
          pressure: current['pressure'],
          wind_speed: current['wind_speed'],
          wind_direction: current['wind_deg'],
          precipitation: extract_precipitation(current),
          cloud_cover: current['clouds'],
          visibility: (current['visibility'] || 10000) / 1000.0,
          weather_description: current['weather'][0]['description'],
          source: 'openweathermap_historical'
        }
      end

      def extract_precipitation(data)
        rain = data.dig('rain', '1h') || data.dig('rain', '3h') || 0
        snow = data.dig('snow', '1h') || data.dig('snow', '3h') || 0
        rain + snow
      end
    end

    # Custom error classes
    class APIError < StandardError; end
    class ConfigurationError < StandardError; end
  end
end