# Weather Station model for managing weather data sources and station metadata
# Represents physical or virtual weather monitoring locations with spatial capabilities
class WeatherStation < ApplicationRecord
  has_many :weather_observations, dependent: :destroy
  has_many :weather_forecasts, dependent: :destroy
  has_many :primary_location_caches, class_name: 'LocationWeatherCache', foreign_key: 'primary_weather_station_id'
  has_many :secondary_location_caches, class_name: 'LocationWeatherCache', foreign_key: 'secondary_weather_station_id'
  has_many :tertiary_location_caches, class_name: 'LocationWeatherCache', foreign_key: 'tertiary_weather_station_id'
  
  # Validations
  validates :station_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :station_type, presence: true, inclusion: { 
    in: %w[metar mesonet virtual api_source radiosonde buoy]
  }
  validates :data_source, presence: true, inclusion: { 
    in: %w[noaa weather_gov openweather weatherapi meteostat internal custom]
  }
  validates :latitude, presence: true, numericality: { 
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90 
  }
  validates :longitude, presence: true, numericality: { 
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180 
  }
  validates :elevation, numericality: { greater_than: -500 }, allow_nil: true
  validates :data_quality_rating, numericality: { in: 1..5 }, allow_nil: true
  validates :coverage_radius, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scopes for efficient querying
  scope :active, -> { where(active: true) }
  scope :by_source, ->(source) { where(data_source: source) }
  scope :by_type, ->(type) { where(station_type: type) }
  scope :high_quality, -> { where('data_quality_rating >= ?', 4) }
  scope :recently_updated, -> { where('last_observation_at > ?', 2.hours.ago) }
  scope :with_current_data, -> { where('last_observation_at > ?', 1.hour.ago) }
  
  # Geographic scopes using spatial queries
  scope :within_radius, ->(lat, lon, radius_km) {
    where(
      "ST_DWithin(ST_Point(longitude, latitude)::geography, ST_Point(?, ?)::geography, ?)",
      lon, lat, radius_km * 1000
    )
  }
  
  scope :nearest_to, ->(lat, lon, limit = 10) {
    select("*, ST_Distance(ST_Point(longitude, latitude)::geography, ST_Point(?, ?)::geography) as distance")
      .where("ST_Point(longitude, latitude) IS NOT NULL")
      .order("distance")
      .limit(limit)
  }
  
  scope :in_bounds, ->(north, south, east, west) {
    where(latitude: south..north, longitude: west..east)
  }
  
  # JSON field accessors with defaults
  def contact_info
    self[:contact_info] || {}
  end
  
  def api_config
    self[:api_config] || {}
  end
  
  def data_processing_config
    self[:data_processing_config] || {
      'quality_control' => true,
      'interpolation_method' => 'inverse_distance',
      'max_age_hours' => 6,
      'required_parameters' => ['temperature', 'wind_speed', 'wind_direction']
    }
  end
  
  # Find nearest weather stations to a given location
  def self.find_nearest_stations(latitude, longitude, max_distance_km = 100, limit = 3)
    active.nearest_to(latitude, longitude, limit * 2)
          .select { |station| station.distance <= max_distance_km * 1000 }
          .first(limit)
  end
  
  # Get stations within a geographic bounding box
  def self.stations_in_area(north, south, east, west)
    active.in_bounds(north, south, east, west)
          .includes(:weather_observations)
          .order(:name)
  end
  
  # Find best station for a location considering data quality and recency
  def self.best_station_for_location(latitude, longitude, max_distance_km = 50)
    candidates = find_nearest_stations(latitude, longitude, max_distance_km, 10)
    
    # Score stations based on quality, recency, and distance
    scored_stations = candidates.map do |station|
      score = calculate_station_score(station, latitude, longitude)
      { station: station, score: score }
    end
    
    # Return highest scoring station
    best = scored_stations.max_by { |s| s[:score] }
    best&.dig(:station)
  end
  
  # Calculate distance to a point in kilometers
  def distance_to(latitude, longitude)
    return nil if self.latitude.nil? || self.longitude.nil?
    
    # Haversine formula for great circle distance
    rad_lat1 = self.latitude * Math::PI / 180
    rad_lat2 = latitude * Math::PI / 180
    delta_lat = (latitude - self.latitude) * Math::PI / 180
    delta_lon = (longitude - self.longitude) * Math::PI / 180
    
    a = Math.sin(delta_lat / 2)**2 + 
        Math.cos(rad_lat1) * Math.cos(rad_lat2) * Math.sin(delta_lon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    6371.0 * c # Earth radius in km
  end
  
  # Get current weather observation
  def current_observation
    weather_observations.where(observation_type: 'current')
                       .order(observed_at: :desc)
                       .first
  end
  
  # Get latest weather observation regardless of type
  def latest_observation
    weather_observations.order(observed_at: :desc).first
  end
  
  # Get current weather forecast
  def current_forecast(hours_ahead = 0)
    weather_forecasts.where(forecast_hour: hours_ahead)
                     .order(forecast_issued_at: :desc)
                     .first
  end
  
  # Check if station has recent data
  def has_recent_data?(max_age_hours = 2)
    last_observation_at.present? && last_observation_at > max_age_hours.hours.ago
  end
  
  # Check if station is suitable for dispersion modeling
  def suitable_for_dispersion?
    active? && 
    has_recent_data? && 
    (data_quality_rating.nil? || data_quality_rating >= 3) &&
    current_observation&.has_required_parameters?
  end
  
  # Get API endpoint configuration
  def api_endpoint
    config = api_config
    case data_source
    when 'noaa'
      "https://api.weather.gov/stations/#{station_id}/observations/latest"
    when 'openweather'
      "https://api.openweathermap.org/data/2.5/weather?lat=#{latitude}&lon=#{longitude}"
    when 'weatherapi'
      "https://api.weatherapi.com/v1/current.json?q=#{latitude},#{longitude}"
    else
      config['endpoint']
    end
  end
  
  # Update station with latest observation metadata
  def update_observation_metadata!(observation_time = Time.current)
    update!(last_observation_at: observation_time)
  end
  
  # Fetch weather data from external API
  def fetch_current_weather!
    case data_source
    when 'noaa'
      fetch_noaa_weather!
    when 'openweather'
      fetch_openweather_data!
    when 'weatherapi'
      fetch_weatherapi_data!
    else
      Rails.logger.warn "Unknown data source: #{data_source}"
      nil
    end
  end
  
  # Export station data for GIS systems
  def to_geojson
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      properties: {
        station_id: station_id,
        name: name,
        station_type: station_type,
        data_source: data_source,
        elevation: elevation,
        active: active,
        data_quality_rating: data_quality_rating,
        coverage_radius: coverage_radius,
        last_observation_at: last_observation_at&.iso8601,
        has_recent_data: has_recent_data?,
        suitable_for_dispersion: suitable_for_dispersion?
      }
    }
  end
  
  # Create virtual weather station for a specific location
  def self.create_virtual_station(latitude, longitude, name: nil)
    station_name = name || "Virtual Station (#{latitude.round(4)}, #{longitude.round(4)})"
    
    create!(
      station_id: generate_virtual_station_id(latitude, longitude),
      name: station_name,
      station_type: 'virtual',
      data_source: 'internal',
      latitude: latitude,
      longitude: longitude,
      active: true,
      data_quality_rating: 3,
      coverage_radius: 10.0, # 10 km default coverage
      established_at: Time.current
    )
  end
  
  # Interpolate weather data from nearby stations
  def interpolate_weather_data(target_latitude, target_longitude, max_stations = 3)
    nearby_stations = self.class.find_nearest_stations(
      target_latitude, target_longitude, coverage_radius || 50.0, max_stations
    ).select(&:has_recent_data?)
    
    return nil if nearby_stations.empty?
    
    # Get observations from nearby stations
    observations = nearby_stations.map(&:current_observation).compact
    return nil if observations.empty?
    
    # Calculate inverse distance weights
    total_weight = 0
    weighted_data = {}
    
    observations.each do |obs|
      distance = obs.weather_station.distance_to(target_latitude, target_longitude)
      next if distance.nil? || distance.zero?
      
      weight = 1.0 / (distance**2) # Inverse distance squared weighting
      total_weight += weight
      
      # Accumulate weighted values for interpolation
      %w[temperature wind_speed wind_direction pressure_sea_level relative_humidity].each do |param|
        value = obs.send(param)
        next if value.nil?
        
        weighted_data[param] ||= 0
        if param == 'wind_direction'
          # Special handling for circular wind direction
          weighted_data[param] += weight * Math.sin(value * Math::PI / 180)
          weighted_data["#{param}_cos"] ||= 0
          weighted_data["#{param}_cos"] += weight * Math.cos(value * Math::PI / 180)
        else
          weighted_data[param] += weight * value
        end
      end
    end
    
    return nil if total_weight.zero?
    
    # Calculate final interpolated values
    interpolated = {}
    weighted_data.each do |param, weighted_sum|
      next if param.end_with?('_cos')
      
      if param == 'wind_direction'
        # Convert back from sin/cos components
        sin_component = weighted_sum / total_weight
        cos_component = weighted_data["#{param}_cos"] / total_weight
        direction = Math.atan2(sin_component, cos_component) * 180 / Math::PI
        direction += 360 if direction < 0
        interpolated[param] = direction
      else
        interpolated[param] = weighted_sum / total_weight
      end
    end
    
    interpolated
  end
  
  # Generate comprehensive station status report
  def generate_status_report
    current_obs = current_observation
    latest_obs = latest_observation
    
    {
      station_info: {
        id: station_id,
        name: name,
        type: station_type,
        data_source: data_source,
        location: [latitude, longitude],
        elevation: elevation,
        timezone: timezone
      },
      operational_status: {
        active: active,
        data_quality_rating: data_quality_rating,
        coverage_radius: coverage_radius,
        suitable_for_dispersion: suitable_for_dispersion?
      },
      data_availability: {
        last_observation_at: last_observation_at,
        has_recent_data: has_recent_data?,
        total_observations: weather_observations.count,
        observations_last_24h: weather_observations.where('observed_at > ?', 24.hours.ago).count
      },
      current_conditions: current_obs&.weather_summary || {},
      api_configuration: {
        endpoint: api_endpoint,
        update_frequency: api_config['update_frequency_minutes'] || 60,
        last_api_call: api_config['last_api_call']
      },
      quality_metrics: {
        data_completeness: calculate_data_completeness,
        parameter_availability: assess_parameter_availability,
        temporal_consistency: assess_temporal_consistency
      }
    }
  end
  
  private
  
  # Calculate station scoring for location selection
  def self.calculate_station_score(station, target_lat, target_lon)
    # Base score from data quality
    quality_score = (station.data_quality_rating || 3) * 0.2
    
    # Recency score (higher for more recent data)
    if station.last_observation_at
      hours_ago = (Time.current - station.last_observation_at) / 1.hour
      recency_score = [0, 1 - (hours_ago / 24.0)].max * 0.3
    else
      recency_score = 0
    end
    
    # Distance score (closer is better)
    distance_km = station.distance || station.distance_to(target_lat, target_lon)
    return 0 if distance_km.nil? || distance_km > 100
    
    distance_score = [0, 1 - (distance_km / 100.0)].max * 0.3
    
    # Station type preference
    type_score = case station.station_type
                when 'metar' then 0.2 # High quality aviation weather
                when 'mesonet' then 0.15 # Good research quality
                when 'api_source' then 0.1 # Depends on source
                else 0.05
                end
    
    quality_score + recency_score + distance_score + type_score
  end
  
  # Generate unique ID for virtual stations
  def self.generate_virtual_station_id(latitude, longitude)
    "VIRTUAL_#{latitude.round(4)}_#{longitude.round(4)}_#{Time.current.to_i}"
  end
  
  # Fetch weather data from NOAA API
  def fetch_noaa_weather!
    require 'net/http'
    require 'json'
    
    uri = URI(api_endpoint)
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      process_noaa_observation(data)
    else
      Rails.logger.error "NOAA API error: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching NOAA weather: #{e.message}"
    nil
  end
  
  # Fetch weather data from OpenWeather API
  def fetch_openweather_data!
    require 'net/http'
    require 'json'
    
    api_key = api_config['api_key'] || Rails.application.credentials.openweather_api_key
    return nil unless api_key
    
    uri = URI("#{api_endpoint}&appid=#{api_key}&units=metric")
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      process_openweather_observation(data)
    else
      Rails.logger.error "OpenWeather API error: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching OpenWeather data: #{e.message}"
    nil
  end
  
  # Process NOAA observation data
  def process_noaa_observation(data)
    properties = data['properties'] || {}
    
    weather_observations.create!(
      observed_at: Time.parse(properties['timestamp']),
      observation_type: 'current',
      data_source: 'noaa',
      data_confidence: 0.9,
      temperature: parse_temperature(properties['temperature']),
      temperature_dewpoint: parse_temperature(properties['dewpoint']),
      relative_humidity: parse_percentage(properties['relativeHumidity']),
      pressure_sea_level: parse_pressure(properties['seaLevelPressure']),
      wind_speed: parse_speed(properties['windSpeed']),
      wind_direction: parse_angle(properties['windDirection']),
      wind_gust_speed: parse_speed(properties['windGust']),
      visibility: parse_length(properties['visibility']),
      weather_condition: properties['textDescription'],
      raw_data: data
    )
  end
  
  # Process OpenWeather observation data
  def process_openweather_observation(data)
    main = data['main'] || {}
    wind = data['wind'] || {}
    weather = data['weather']&.first || {}
    
    weather_observations.create!(
      observed_at: Time.at(data['dt']),
      observation_type: 'current',
      data_source: 'openweather',
      data_confidence: 0.85,
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
      raw_data: data
    )
  end
  
  # Helper methods for parsing weather data
  def parse_temperature(temp_data)
    return nil if temp_data.nil?
    value = temp_data.is_a?(Hash) ? temp_data['value'] : temp_data
    return nil if value.nil?
    
    # Convert from various units to Celsius
    unit = temp_data.is_a?(Hash) ? temp_data['unitCode'] : 'wmoUnit:degC'
    case unit
    when 'wmoUnit:K'
      value - 273.15
    when 'wmoUnit:degF'
      (value - 32) * 5.0 / 9.0
    else
      value # Assume Celsius
    end
  end
  
  def parse_pressure(pressure_data)
    return nil if pressure_data.nil?
    value = pressure_data.is_a?(Hash) ? pressure_data['value'] : pressure_data
    return nil if value.nil?
    
    # Convert to hPa
    unit = pressure_data.is_a?(Hash) ? pressure_data['unitCode'] : 'wmoUnit:Pa'
    case unit
    when 'wmoUnit:Pa'
      value / 100.0
    else
      value # Assume hPa
    end
  end
  
  def parse_speed(speed_data)
    return nil if speed_data.nil?
    value = speed_data.is_a?(Hash) ? speed_data['value'] : speed_data
    return nil if value.nil?
    
    # Convert to m/s
    unit = speed_data.is_a?(Hash) ? speed_data['unitCode'] : 'wmoUnit:m_s-1'
    case unit
    when 'wmoUnit:km_h-1'
      value / 3.6
    when 'wmoUnit:mi_h-1'
      value * 0.44704
    else
      value # Assume m/s
    end
  end
  
  def parse_angle(angle_data)
    return nil if angle_data.nil?
    value = angle_data.is_a?(Hash) ? angle_data['value'] : angle_data
    value
  end
  
  def parse_length(length_data)
    return nil if length_data.nil?
    value = length_data.is_a?(Hash) ? length_data['value'] : length_data
    value
  end
  
  def parse_percentage(percent_data)
    return nil if percent_data.nil?
    value = percent_data.is_a?(Hash) ? percent_data['value'] : percent_data
    value
  end
  
  # Calculate dewpoint from temperature and humidity
  def calculate_dewpoint(temp_c, humidity_pct)
    return nil if temp_c.nil? || humidity_pct.nil?
    
    # Magnus formula approximation
    a = 17.625
    b = 243.04
    
    alpha = Math.log(humidity_pct / 100.0) + (a * temp_c) / (b + temp_c)
    (b * alpha) / (a - alpha)
  end
  
  # Calculate data completeness metrics
  def calculate_data_completeness
    return 0 if weather_observations.empty?
    
    recent_obs = weather_observations.where('observed_at > ?', 24.hours.ago)
    return 0 if recent_obs.empty?
    
    required_params = %w[temperature wind_speed wind_direction]
    complete_observations = recent_obs.select do |obs|
      required_params.all? { |param| obs.send(param).present? }
    end
    
    (complete_observations.count.to_f / recent_obs.count * 100).round(1)
  end
  
  # Assess parameter availability
  def assess_parameter_availability
    return {} if weather_observations.empty?
    
    recent_obs = weather_observations.where('observed_at > ?', 24.hours.ago).limit(100)
    params = %w[temperature wind_speed wind_direction pressure_sea_level relative_humidity]
    
    availability = {}
    params.each do |param|
      available_count = recent_obs.count { |obs| obs.send(param).present? }
      availability[param] = (available_count.to_f / recent_obs.count * 100).round(1)
    end
    
    availability
  end
  
  # Assess temporal consistency of data
  def assess_temporal_consistency
    recent_obs = weather_observations.where('observed_at > ?', 12.hours.ago)
                                   .order(observed_at: :desc)
                                   .limit(12)
    
    return 0 if recent_obs.count < 3
    
    # Check for reasonable temporal variations
    temp_variations = []
    wind_variations = []
    
    recent_obs.each_cons(2) do |newer, older|
      next unless newer.temperature && older.temperature
      temp_diff = (newer.temperature - older.temperature).abs
      time_diff = (newer.observed_at - older.observed_at) / 1.hour
      
      # Expect reasonable temperature change rates (< 5°C/hour)
      temp_variations << (temp_diff / time_diff < 5.0)
      
      if newer.wind_speed && older.wind_speed
        wind_diff = (newer.wind_speed - older.wind_speed).abs
        # Expect reasonable wind speed change rates (< 10 m/s per hour)
        wind_variations << (wind_diff / time_diff < 10.0)
      end
    end
    
    consistency_score = 0
    consistency_score += temp_variations.count(true) / temp_variations.count.to_f * 50 if temp_variations.any?
    consistency_score += wind_variations.count(true) / wind_variations.count.to_f * 50 if wind_variations.any?
    
    consistency_score.round(1)
  end
end