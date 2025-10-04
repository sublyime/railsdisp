# National Weather Service API Integration
# Handles interactions with weather.gov API for US locations
# Provides high-quality government weather data

require 'net/http'
require 'json'

module WeatherProviders
  class NationalWeatherService
    BASE_URL = 'https://api.weather.gov'
    
    class << self
      # Fetch current weather conditions for US locations
      def fetch_current_weather(latitude, longitude)
        station_id = find_nearest_station(latitude, longitude)
        observations_url = "#{BASE_URL}/stations/#{station_id}/observations/latest"
        
        response = make_request(observations_url)
        parse_observation_response(response)
      end

      # Fetch detailed forecast for US locations
      def fetch_forecast(latitude, longitude, hours = 24)
        grid_data = get_grid_coordinates(latitude, longitude)
        forecast_url = "#{BASE_URL}/gridpoints/#{grid_data['office']}/#{grid_data['gridX']},#{grid_data['gridY']}/forecast/hourly"
        
        response = make_request(forecast_url)
        parse_forecast_response(response, hours)
      end

      # Check if coordinates are within NWS coverage (US territory)
      def covers_location?(latitude, longitude)
        # Rough check for US territory
        latitude.between?(18.0, 72.0) && longitude.between?(-180.0, -60.0)
      end

      private

      def make_request(url)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 15
        http.open_timeout = 10

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'ChemicalDispersionApp/1.0 (contact@example.com)'
        
        response = http.request(request)

        unless response.code.to_i == 200
          raise APIError, "NWS API error: #{response.code} - #{response.body}"
        end

        JSON.parse(response.body)
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        raise APIError, "NWS API timeout: #{e.message}"
      rescue JSON::ParserError => e
        raise APIError, "Invalid JSON response from NWS: #{e.message}"
      end

      def find_nearest_station(latitude, longitude)
        stations_url = "#{BASE_URL}/points/#{latitude},#{longitude}/stations"
        response = make_request(stations_url)
        
        features = response.dig('features')
        return nil if features.nil? || features.empty?
        
        # Return the first (closest) station ID
        features.first.dig('properties', 'stationIdentifier')
      end

      def get_grid_coordinates(latitude, longitude)
        points_url = "#{BASE_URL}/points/#{latitude},#{longitude}"
        response = make_request(points_url)
        
        properties = response['properties']
        {
          'office' => properties['gridId'],
          'gridX' => properties['gridX'],
          'gridY' => properties['gridY']
        }
      end

      def parse_observation_response(data)
        properties = data['properties']
        
        {
          timestamp: Time.parse(properties['timestamp']),
          temperature: convert_temperature(properties['temperature']),
          humidity: extract_value(properties['relativeHumidity']),
          pressure: convert_pressure(properties['barometricPressure']),
          wind_speed: convert_wind_speed(properties['windSpeed']),
          wind_direction: extract_value(properties['windDirection']),
          precipitation: 0, # Not available in current observations
          cloud_cover: parse_cloud_cover(properties['cloudLayers']),
          visibility: convert_visibility(properties['visibility']),
          weather_description: extract_weather_description(properties),
          source: 'nws'
        }
      end

      def parse_forecast_response(data, hours)
        periods = data['properties']['periods'].first(hours)
        
        periods.map do |period|
          {
            timestamp: Time.parse(period['startTime']),
            temperature: period['temperature'],
            humidity: period['relativeHumidity']['value'] || 50,
            pressure: 1013.25, # Default, not provided in hourly forecast
            wind_speed: parse_wind_speed(period['windSpeed']),
            wind_direction: parse_wind_direction(period['windDirection']),
            precipitation: parse_precipitation_probability(period),
            cloud_cover: 50, # Default, not detailed in forecast
            visibility: 10.0, # Default
            weather_description: period['shortForecast'],
            source: 'nws_forecast'
          }
        end
      end

      # Unit conversion helpers
      def convert_temperature(temp_data)
        return nil unless temp_data && temp_data['value']
        
        case temp_data['unitCode']
        when 'wmoUnit:degC'
          temp_data['value']
        when 'wmoUnit:degF'
          (temp_data['value'] - 32) * 5.0 / 9.0
        when 'wmoUnit:K'
          temp_data['value'] - 273.15
        else
          temp_data['value']
        end
      end

      def convert_pressure(pressure_data)
        return 1013.25 unless pressure_data && pressure_data['value']
        
        case pressure_data['unitCode']
        when 'wmoUnit:Pa'
          pressure_data['value'] / 100.0 # Convert to hPa
        when 'wmoUnit:hPa'
          pressure_data['value']
        else
          pressure_data['value']
        end
      end

      def convert_wind_speed(wind_data)
        return 0 unless wind_data && wind_data['value']
        
        case wind_data['unitCode']
        when 'wmoUnit:km_h-1'
          wind_data['value'] / 3.6 # Convert to m/s
        when 'wmoUnit:m_s-1'
          wind_data['value']
        when 'wmoUnit:mi_h-1'
          wind_data['value'] * 0.44704 # Convert mph to m/s
        else
          wind_data['value']
        end
      end

      def convert_visibility(visibility_data)
        return 10.0 unless visibility_data && visibility_data['value']
        
        case visibility_data['unitCode']
        when 'wmoUnit:m'
          visibility_data['value'] / 1000.0 # Convert to km
        when 'wmoUnit:km'
          visibility_data['value']
        else
          visibility_data['value']
        end
      end

      def extract_value(data)
        data && data['value'] ? data['value'] : nil
      end

      def parse_cloud_cover(cloud_layers)
        return 0 unless cloud_layers && cloud_layers.any?
        
        # Estimate total cloud cover from layers
        total_coverage = cloud_layers.sum do |layer|
          amount = layer.dig('amount', 'value') || 0
          case layer.dig('amount', 'unitCode')
          when 'wmoUnit:percent'
            amount
          else
            # Convert text descriptions to percentages
            case amount.to_s.downcase
            when 'clear', 'skc' then 0
            when 'few' then 25
            when 'scattered', 'sct' then 50
            when 'broken', 'bkn' then 75
            when 'overcast', 'ovc' then 100
            else 50
            end
          end
        end
        
        [total_coverage, 100].min
      end

      def extract_weather_description(properties)
        text_description = properties['textDescription']
        return text_description if text_description
        
        # Fallback to constructing from available data
        conditions = []
        conditions << properties.dig('weather', 0, 'weather') if properties['weather']
        conditions.join(', ')
      end

      def parse_wind_speed(wind_speed_str)
        return 0 unless wind_speed_str
        
        # Extract numeric value from strings like "10 mph", "5 to 10 mph"
        numbers = wind_speed_str.scan(/\d+/).map(&:to_f)
        return 0 if numbers.empty?
        
        # Take average if range given
        avg_mph = numbers.sum / numbers.length
        avg_mph * 0.44704 # Convert mph to m/s
      end

      def parse_wind_direction(wind_direction_str)
        return 0 unless wind_direction_str
        
        direction_map = {
          'N' => 0, 'NNE' => 22.5, 'NE' => 45, 'ENE' => 67.5,
          'E' => 90, 'ESE' => 112.5, 'SE' => 135, 'SSE' => 157.5,
          'S' => 180, 'SSW' => 202.5, 'SW' => 225, 'WSW' => 247.5,
          'W' => 270, 'WNW' => 292.5, 'NW' => 315, 'NNW' => 337.5
        }
        
        direction_map[wind_direction_str] || 0
      end

      def parse_precipitation_probability(period)
        prob = period.dig('probabilityOfPrecipitation', 'value') || 0
        prob / 100.0 # Convert percentage to decimal
      end
    end

    class APIError < StandardError; end
  end
end