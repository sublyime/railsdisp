# Weather Service for fetching real-time weather data from external APIs
# Integrates with multiple weather data sources based on dispersion location
class WeatherService
  include ActiveModel::Model
  
  # Configuration for different weather APIs
  API_SOURCES = {
    'noaa' => {
      name: 'NOAA Weather Service',
      base_url: 'https://api.weather.gov',
      requires_key: false,
      rate_limit: 60, # requests per minute
      coverage: 'US only'
    },
    'openweather' => {
      name: 'OpenWeatherMap',
      base_url: 'https://api.openweathermap.org/data/2.5',
      requires_key: true,
      rate_limit: 1000, # requests per minute for free tier
      coverage: 'Global'
    },
    'weatherapi' => {
      name: 'WeatherAPI',
      base_url: 'https://api.weatherapi.com/v1',
      requires_key: true,
      rate_limit: 1000,
      coverage: 'Global'
    },
    'meteostat' => {
      name: 'Meteostat',
      base_url: 'https://meteostat.p.rapidapi.com',
      requires_key: true,
      rate_limit: 500,
      coverage: 'Global historical'
    }
  }.freeze
  
  attr_accessor :latitude, :longitude, :preferred_sources, :cache_duration
  
  def initialize(latitude: nil, longitude: nil, preferred_sources: nil, cache_duration: 30.minutes)
    @latitude = latitude
    @longitude = longitude
    @preferred_sources = preferred_sources || default_source_priority
    @cache_duration = cache_duration
    @http_client = setup_http_client
  end
  
  # Main method to get weather data for a specific location
  def get_weather_for_location(lat, lon, options = {})
    @latitude = lat
    @longitude = lon
    
    Rails.logger.info "Fetching weather data for location: #{lat}, #{lon}"
    
    # Check cache first
    cached_data = get_cached_weather_data(lat, lon)
    return cached_data if cached_data && !options[:force_refresh]
    
    # Find or create weather stations for this location
    weather_stations = find_or_create_weather_stations(lat, lon)
    
    # Fetch fresh data from multiple sources
    weather_data = fetch_multi_source_weather_data(lat, lon, weather_stations)
    
    if weather_data
      # Cache the results
      cache_weather_data(lat, lon, weather_data)
      
      # Create weather observations in database
      save_weather_observations(weather_stations, weather_data)
      
      weather_data
    else
      Rails.logger.error "Failed to fetch weather data for #{lat}, #{lon}"
      nil
    end
  end
  
  # Get weather data specifically for a dispersion scenario
  def get_weather_for_dispersion(dispersion_scenario)
    lat = dispersion_scenario.latitude
    lon = dispersion_scenario.longitude
    
    Rails.logger.info "Fetching weather for dispersion scenario #{dispersion_scenario.id} at #{lat}, #{lon}"
    
    # Get current weather data
    current_weather = get_weather_for_location(lat, lon)
    return nil unless current_weather
    
    # Also fetch forecast data for scenario planning
    forecast_data = fetch_forecast_data(lat, lon)
    
    # Create comprehensive weather package for dispersion modeling
    dispersion_weather = {
      current_conditions: current_weather,
      forecast_conditions: forecast_data,
      atmospheric_stability: calculate_stability_for_dispersion(current_weather),
      dispersion_parameters: generate_dispersion_parameters(current_weather),
      location: { latitude: lat, longitude: lon },
      scenario_id: dispersion_scenario.id,
      fetched_at: Time.current
    }
    
    # Associate weather data with the scenario
    associate_weather_with_scenario(dispersion_scenario, dispersion_weather)
    
    dispersion_weather
  end
  
  # Find or create weather stations near the specified location
  def find_or_create_weather_stations(lat, lon, search_radius_km = 50)
    # Find existing nearby stations
    nearby_stations = WeatherStation.find_nearest_stations(lat, lon, search_radius_km, 5)
    
    # If no nearby stations with recent data, create virtual stations
    active_stations = nearby_stations.select(&:has_recent_data?)
    
    if active_stations.empty?
      Rails.logger.info "No active weather stations found near #{lat}, #{lon}, creating virtual station"
      
      # Create virtual weather station for this location
      virtual_station = create_virtual_weather_station(lat, lon)
      [virtual_station]
    else
      Rails.logger.info "Found #{active_stations.count} active weather stations near #{lat}, #{lon}"
      active_stations
    end
  end
  
  # Create virtual weather station for a specific location
  def create_virtual_weather_station(lat, lon)
    # Determine best data source for this location
    best_source = determine_best_data_source(lat, lon)
    
    station = WeatherStation.create!(
      station_id: "VIRTUAL_#{lat.round(4)}_#{lon.round(4)}_#{Time.current.to_i}",
      name: "Virtual Station - #{lat.round(4)}, #{lon.round(4)}",
      station_type: 'virtual',
      data_source: best_source,
      latitude: lat,
      longitude: lon,
      active: true,
      data_quality_rating: 3,
      coverage_radius: 25.0,
      established_at: Time.current,
      api_config: {
        'update_frequency_minutes' => 30,
        'auto_fetch' => true,
        'primary_source' => best_source
      }.to_json
    )
    
    Rails.logger.info "Created virtual weather station: #{station.station_id}"
    station
  end
  
  # Fetch weather data from multiple sources
  def fetch_multi_source_weather_data(lat, lon, weather_stations)
    weather_data = {}
    errors = []
    
    @preferred_sources.each do |source|
      begin
        Rails.logger.info "Attempting to fetch weather from #{source}"
        
        data = case source
              when 'noaa'
                fetch_noaa_weather(lat, lon)
              when 'openweather'
                fetch_openweather_data(lat, lon)
              when 'weatherapi'
                fetch_weatherapi_data(lat, lon)
              when 'meteostat'
                fetch_meteostat_data(lat, lon)
              else
                Rails.logger.warn "Unknown weather source: #{source}"
                nil
              end
        
        if data
          weather_data[source] = data
          Rails.logger.info "Successfully fetched weather from #{source}"
        else
          errors << "#{source}: No data returned"
        end
        
      rescue StandardError => e
        error_msg = "#{source}: #{e.message}"
        Rails.logger.error "Weather API error - #{error_msg}"
        errors << error_msg
      end
      
      # Rate limiting
      sleep(1) if @preferred_sources.count > 1
    end
    
    if weather_data.empty?
      Rails.logger.error "All weather sources failed: #{errors.join(', ')}"
      return nil
    end
    
    # Combine and validate data from multiple sources
    combined_data = combine_weather_data(weather_data)
    combined_data[:source_errors] = errors if errors.any?
    
    combined_data
  end
  
  # Fetch weather data from NOAA Weather Service API
  def fetch_noaa_weather(lat, lon)
    # NOAA API requires a two-step process: get grid point, then forecast
    
    # Step 1: Get grid point information
    grid_response = @http_client.get("#{API_SOURCES['noaa'][:base_url]}/points/#{lat},#{lon}")
    return nil unless grid_response.success?
    
    grid_data = JSON.parse(grid_response.body)
    properties = grid_data['properties']
    
    # Step 2: Get current observations from nearest station
    stations_url = properties['observationStations']
    stations_response = @http_client.get(stations_url)
    return nil unless stations_response.success?
    
    stations_data = JSON.parse(stations_response.body)
    station_urls = stations_data.dig('features')&.map { |f| f.dig('id') }
    return nil if station_urls.empty?
    
    # Get latest observation from first available station
    station_urls.first(3).each do |station_url|
      obs_response = @http_client.get("#{station_url}/observations/latest")
      next unless obs_response.success?
      
      obs_data = JSON.parse(obs_response.body)
      return process_noaa_observation(obs_data) if obs_data.dig('properties')
    end
    
    nil
  rescue StandardError => e
    Rails.logger.error "NOAA weather fetch error: #{e.message}"
    nil
  end
  
  # Fetch weather data from OpenWeatherMap API
  def fetch_openweather_data(lat, lon)
    api_key = Rails.application.credentials.openweather_api_key
    return nil unless api_key
    
    url = "#{API_SOURCES['openweather'][:base_url]}/weather"
    params = {
      lat: lat,
      lon: lon,
      appid: api_key,
      units: 'metric'
    }
    
    response = @http_client.get(url, params: params)
    return nil unless response.success?
    
    data = JSON.parse(response.body)
    process_openweather_observation(data)
    
  rescue StandardError => e
    Rails.logger.error "OpenWeather fetch error: #{e.message}"
    nil
  end
  
  # Combine weather data from multiple sources
  def combine_weather_data(source_data)
    return nil if source_data.empty?
    
    # Use highest confidence source as primary
    primary_source = source_data.max_by { |_, data| data[:data_confidence] || 0 }
    combined = primary_source[1].dup
    
    # Fill in missing data from other sources
    source_data.each do |source, data|
      next if source == primary_source[0]
      
      data.each do |key, value|
        if combined[key].nil? && value.present? && key != :raw_data
          combined[key] = value
          combined[:supplemented_by] ||= []
          combined[:supplemented_by] << "#{key}:#{source}"
        end
      end
    end
    
    # Calculate atmospheric stability if not already done
    combined[:pasquill_stability_class] ||= calculate_pasquill_stability(combined)
    
    # Add quality assessment
    combined[:data_quality] = assess_data_quality(combined)
    combined[:sources_used] = source_data.keys
    combined[:primary_source] = primary_source[0]
    
    combined
  end
  
  # Calculate Pasquill stability class from weather data
  def calculate_pasquill_stability(weather_data)
    wind_speed = weather_data[:wind_speed]
    cloud_cover = weather_data[:cloud_cover_total]
    observed_at = weather_data[:observed_at]
    
    return nil unless wind_speed && observed_at
    
    # Determine if daytime
    hour = observed_at.hour
    is_daytime = hour.between?(6, 18)
    
    if is_daytime
      # Daytime stability based on cloud cover and wind speed
      insolation = if cloud_cover
                    case cloud_cover
                    when 0...30 then :strong
                    when 30...70 then :moderate
                    when 70...95 then :slight
                    else :overcast
                    end
                  else
                    # Estimate from time of day
                    case hour
                    when 10..14 then :strong
                    when 8..16 then :moderate
                    else :slight
                    end
                  end
      
      case insolation
      when :strong
        case wind_speed
        when 0...2 then 'A'
        when 2...3 then 'A'
        when 3...4 then 'B'
        when 4...6 then 'C'
        else 'D'
        end
      when :moderate
        case wind_speed
        when 0...2 then 'A'
        when 2...3 then 'B'
        when 3...5 then 'B'
        when 5...6 then 'C'
        else 'D'
        end
      when :slight
        case wind_speed
        when 0...2 then 'B'
        when 2...5 then 'C'
        else 'D'
        end
      else
        'D' # Overcast
      end
    else
      # Nighttime stability
      clear_night = cloud_cover.nil? || cloud_cover < 50
      
      if clear_night
        case wind_speed
        when 0...2 then 'F'
        when 2...3 then 'F'
        when 3...5 then 'E'
        else 'D'
        end
      else
        case wind_speed
        when 0...2 then 'E'
        when 2...5 then 'E'
        else 'D'
        end
      end
    end
  end
  
  # Class methods for backward compatibility and static functionality
  class << self
    # Fetch weather data for a specific location (backward compatibility)
    def fetch_weather_data(latitude, longitude)
      service = new(latitude: latitude, longitude: longitude)
      service.get_weather_for_location(latitude, longitude)
    end

    # Fetch forecast data for dispersion planning (backward compatibility)
    def fetch_forecast_data(latitude, longitude, hours = 24)
      service = new(latitude: latitude, longitude: longitude)
      service.fetch_forecast_data(latitude, longitude)
    end

    # Update weather data for all monitored locations
    def update_all_locations
      # Find all recent dispersion scenarios to update weather for
      DispersionScenario.where('created_at > ?', 24.hours.ago).find_each do |scenario|
        begin
          service = new(latitude: scenario.latitude, longitude: scenario.longitude)
          weather_data = service.get_weather_for_location(scenario.latitude, scenario.longitude)
          
          if weather_data
            Rails.logger.info "Updated weather for scenario #{scenario.id}"
          else
            Rails.logger.warn "Failed to update weather for scenario #{scenario.id}"
          end
        rescue => e
          Rails.logger.error "Failed to update weather for scenario #{scenario.id}: #{e.message}"
        end
      end
    end

    # Calculate atmospheric stability class from weather data (backward compatibility)
    def calculate_stability_class(weather_data)
      service = new
      service.calculate_pasquill_stability(weather_data)
    end
  end
  
  private
  
  # Default priority order for weather data sources
  def default_source_priority
    # Prefer NOAA for US locations, OpenWeather for global
    if us_location?(@latitude, @longitude)
      %w[noaa openweather weatherapi]
    else
      %w[openweather weatherapi meteostat]
    end
  end
  
  # Check if location is within the United States
  def us_location?(lat, lon)
    return false unless lat && lon
    
    # Simplified US bounding box check
    lat.between?(24.0, 71.0) && lon.between?(-180.0, -66.0)
  end
  
  # Determine best data source for location
  def determine_best_data_source(lat, lon)
    if us_location?(lat, lon)
      'noaa'
    else
      'openweather'
    end
  end
  
  # Setup HTTP client with reasonable timeouts
  def setup_http_client
    Faraday.new do |faraday|
      faraday.options.timeout = 30
      faraday.options.open_timeout = 10
      faraday.adapter Faraday.default_adapter
    end
  end
  
  # Process NOAA observation data
  def process_noaa_observation(data)
    props = data.dig('properties')
    return nil unless props
    
    {
      source: 'noaa',
      observed_at: Time.parse(props['timestamp']),
      temperature: convert_temperature(props['temperature']),
      temperature_dewpoint: convert_temperature(props['dewpoint']),
      relative_humidity: convert_percentage(props['relativeHumidity']),
      pressure_sea_level: convert_pressure(props['seaLevelPressure']),
      wind_speed: convert_speed(props['windSpeed']),
      wind_direction: convert_angle(props['windDirection']),
      wind_gust_speed: convert_speed(props['windGust']),
      visibility: convert_distance(props['visibility']),
      weather_condition: props['textDescription'],
      data_confidence: 0.9,
      raw_data: data
    }
  end
  
  # Process OpenWeatherMap observation data
  def process_openweather_observation(data)
    main = data['main'] || {}
    wind = data['wind'] || {}
    weather = data['weather']&.first || {}
    
    {
      source: 'openweather',
      observed_at: Time.at(data['dt']),
      temperature: main['temp'],
      temperature_dewpoint: calculate_dewpoint(main['temp'], main['humidity']),
      relative_humidity: main['humidity'],
      pressure_sea_level: main['pressure'],
      wind_speed: wind['speed'],
      wind_direction: wind['deg'],
      wind_gust_speed: wind['gust'],
      visibility: data['visibility'],
      cloud_cover_total: data.dig('clouds', 'all'),
      weather_condition: weather['description'],
      solar_radiation: estimate_solar_radiation(data),
      data_confidence: 0.85,
      raw_data: data
    }
  end
  
  # Save weather observations to database
  def save_weather_observations(weather_stations, weather_data)
    weather_stations.each do |station|
      begin
        observation = station.weather_observations.create!(
          observed_at: weather_data[:observed_at],
          observation_type: 'current',
          data_source: weather_data[:primary_source],
          data_confidence: weather_data[:data_confidence],
          temperature: weather_data[:temperature],
          temperature_dewpoint: weather_data[:temperature_dewpoint],
          relative_humidity: weather_data[:relative_humidity],
          pressure_sea_level: weather_data[:pressure_sea_level],
          wind_speed: weather_data[:wind_speed],
          wind_direction: weather_data[:wind_direction],
          wind_gust_speed: weather_data[:wind_gust_speed],
          visibility: weather_data[:visibility],
          cloud_cover_total: weather_data[:cloud_cover_total],
          weather_condition: weather_data[:weather_condition],
          pasquill_stability_class: weather_data[:pasquill_stability_class],
          solar_radiation: weather_data[:solar_radiation],
          quality_flags: { sources_used: weather_data[:sources_used] }.to_json,
          raw_data: weather_data[:raw_data].to_json
        )
        
        # Update station metadata
        station.update_observation_metadata!(weather_data[:observed_at])
        
        Rails.logger.info "Saved weather observation for station #{station.station_id}"
        
      rescue StandardError => e
        Rails.logger.error "Failed to save weather observation: #{e.message}"
      end
    end
  end
  
  # Generate comprehensive dispersion parameters
  def generate_dispersion_parameters(weather_data)
    {
      meteorology: {
        wind_speed: weather_data[:wind_speed],
        wind_direction: weather_data[:wind_direction],
        temperature: weather_data[:temperature],
        pressure: weather_data[:pressure_sea_level],
        humidity: weather_data[:relative_humidity],
        stability_class: weather_data[:pasquill_stability_class]
      },
      atmospheric_stability: calculate_stability_for_dispersion(weather_data),
      data_quality: {
        confidence: weather_data[:data_confidence],
        primary_source: weather_data[:primary_source],
        sources_used: weather_data[:sources_used],
        observed_at: weather_data[:observed_at]
      }
    }
  end
  
  # Calculate dispersion parameters from weather data
  def calculate_stability_for_dispersion(weather_data)
    stability_class = weather_data[:pasquill_stability_class]
    return {} unless stability_class
    
    {
      stability_class: stability_class,
      stability_description: get_stability_description(stability_class),
      mixing_height: estimate_mixing_height(weather_data),
      dispersion_coefficients: get_dispersion_coefficients(stability_class),
      atmospheric_conditions: classify_atmospheric_conditions(weather_data)
    }
  end
  
  # Unit conversion helpers
  def convert_temperature(temp_data)
    return nil if temp_data.nil?
    
    if temp_data.is_a?(Hash)
      value = temp_data['value']
      unit = temp_data['unitCode']
      
      case unit
      when 'wmoUnit:K' then value - 273.15
      when 'wmoUnit:degF' then (value - 32) * 5.0 / 9.0
      else value
      end
    else
      temp_data
    end
  end
  
  def convert_pressure(pressure_data)
    return nil if pressure_data.nil?
    
    if pressure_data.is_a?(Hash)
      value = pressure_data['value']
      unit = pressure_data['unitCode']
      
      case unit
      when 'wmoUnit:Pa' then value / 100.0
      else value
      end
    else
      pressure_data
    end
  end
  
  def convert_speed(speed_data)
    return nil if speed_data.nil?
    
    if speed_data.is_a?(Hash)
      value = speed_data['value']
      unit = speed_data['unitCode']
      
      case unit
      when 'wmoUnit:km_h-1' then value / 3.6
      when 'wmoUnit:mi_h-1' then value * 0.44704
      else value
      end
    else
      speed_data
    end
  end
  
  def convert_angle(angle_data)
    return nil if angle_data.nil?
    
    if angle_data.is_a?(Hash)
      angle_data['value']
    else
      angle_data
    end
  end
  
  def convert_distance(distance_data)
    return nil if distance_data.nil?
    
    if distance_data.is_a?(Hash)
      distance_data['value']
    else
      distance_data
    end
  end
  
  def convert_percentage(percent_data)
    return nil if percent_data.nil?
    
    if percent_data.is_a?(Hash)
      percent_data['value']
    else
      percent_data
    end
  end
  
  # Calculate dewpoint from temperature and humidity
  def calculate_dewpoint(temp_c, humidity_pct)
    return nil unless temp_c && humidity_pct
    
    a = 17.625
    b = 243.04
    
    alpha = Math.log(humidity_pct / 100.0) + (a * temp_c) / (b + temp_c)
    (b * alpha) / (a - alpha)
  end
  
  # Helper methods
  def get_stability_description(stability_class)
    descriptions = {
      'A' => 'Very Unstable',
      'B' => 'Moderately Unstable',
      'C' => 'Slightly Unstable',
      'D' => 'Neutral',
      'E' => 'Slightly Stable',
      'F' => 'Moderately Stable'
    }
    
    descriptions[stability_class] || 'Unknown'
  end
  
  def estimate_mixing_height(weather_data)
    stability = weather_data[:pasquill_stability_class]
    return 1000 unless stability
    
    case stability
    when 'A' then 2000
    when 'B' then 1500
    when 'C' then 1000
    when 'D' then 800
    when 'E' then 400
    when 'F' then 200
    else 1000
    end
  end
  
  def get_dispersion_coefficients(stability_class)
    coefficients = {
      'A' => { sigma_y: { a: 0.22, b: 0.0001 }, sigma_z: { c: 0.20, d: 0.0 } },
      'B' => { sigma_y: { a: 0.16, b: 0.0001 }, sigma_z: { c: 0.12, d: 0.0 } },
      'C' => { sigma_y: { a: 0.11, b: 0.0001 }, sigma_z: { c: 0.08, d: 0.0002 } },
      'D' => { sigma_y: { a: 0.08, b: 0.0001 }, sigma_z: { c: 0.06, d: 0.0015 } },
      'E' => { sigma_y: { a: 0.06, b: 0.0001 }, sigma_z: { c: 0.03, d: 0.0003 } },
      'F' => { sigma_y: { a: 0.04, b: 0.0001 }, sigma_z: { c: 0.016, d: 0.0003 } }
    }
    
    coefficients[stability_class] || coefficients['D']
  end
  
  def classify_atmospheric_conditions(weather_data)
    conditions = []
    
    wind_speed = weather_data[:wind_speed] || 0
    case wind_speed
    when 0...1 then conditions << 'calm'
    when 1...3 then conditions << 'light_wind'
    when 3...7 then conditions << 'moderate_wind'
    when 7...15 then conditions << 'strong_wind'
    else conditions << 'very_strong_wind'
    end
    
    stability = weather_data[:pasquill_stability_class]
    if stability.in?(['A', 'B'])
      conditions << 'unstable_atmosphere'
    elsif stability == 'D'
      conditions << 'neutral_atmosphere'
    elsif stability.in?(['E', 'F'])
      conditions << 'stable_atmosphere'
    end
    
    conditions
  end
  
  def assess_data_quality(weather_data)
    score = 0
    
    score += (weather_data[:data_confidence] || 0.5) * 50
    
    if weather_data[:observed_at] && weather_data[:observed_at] > 1.hour.ago
      score += 20
    end
    
    required_params = [:temperature, :wind_speed, :wind_direction]
    complete_params = required_params.count { |param| weather_data[param].present? }
    score += (complete_params.to_f / required_params.count) * 20
    
    sources_count = weather_data[:sources_used]&.count || 1
    score += [sources_count * 2, 10].min
    
    [score, 100].min.round(1)
  end
  
  def estimate_solar_radiation(data)
    return nil unless data['dt']
    
    time = Time.at(data['dt'])
    hour = time.hour
    cloud_cover = data.dig('clouds', 'all') || 0
    
    if hour.between?(6, 18)
      max_radiation = case hour
                     when 11..13 then 1000
                     when 10, 14 then 800
                     when 9, 15 then 600
                     when 8, 16 then 400
                     else 200
                     end
      
      max_radiation * (1 - cloud_cover / 100.0 * 0.8)
    else
      0
    end
  end
  
  def cache_weather_data(lat, lon, data)
    cache_key = "weather_#{lat.round(4)}_#{lon.round(4)}"
    Rails.cache.write(cache_key, data, expires_in: @cache_duration)
  end
  
  def get_cached_weather_data(lat, lon)
    cache_key = "weather_#{lat.round(4)}_#{lon.round(4)}"
    Rails.cache.read(cache_key)
  end
  
  def fetch_forecast_data(lat, lon)
    {} # Placeholder for forecast implementation
  end
  
  def associate_weather_with_scenario(scenario, weather_data)
    # Find weather observations for this scenario location
    observations = WeatherObservation.for_location(
      scenario.latitude, scenario.longitude, 25.0
    ).recent.limit(5)
    
    # Associate the most recent relevant observations
    observations.each do |obs|
      obs.update!(dispersion_scenario: scenario)
    end
    
    Rails.logger.info "Associated #{observations.count} weather observations with scenario #{scenario.id}"
  end
end