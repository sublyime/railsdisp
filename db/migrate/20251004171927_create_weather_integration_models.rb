class CreateWeatherIntegrationModels < ActiveRecord::Migration[8.0]
  def change
    # Weather stations table - physical or virtual weather monitoring locations
    create_table :weather_stations do |t|
      t.string :station_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :station_type, null: false # 'metar', 'mesonet', 'virtual', 'api_source'
      t.string :data_source, null: false # 'noaa', 'weather_gov', 'openweather', 'internal'
      
      # Geographic location
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.decimal :elevation, precision: 8, scale: 2 # meters above sea level
      
      # Station metadata
      t.string :country_code, limit: 2
      t.string :state_code, limit: 3
      t.string :timezone
      t.json :contact_info # Station operator contact details
      
      # Data quality and availability
      t.boolean :active, default: true
      t.integer :data_quality_rating # 1-5 rating
      t.decimal :coverage_radius, precision: 8, scale: 2 # km coverage area
      t.datetime :last_observation_at
      t.datetime :established_at
      
      # API configuration for external data sources
      t.json :api_config # API endpoints, keys, refresh intervals
      t.json :data_processing_config # Quality control, interpolation settings
      
      t.timestamps
    end
    
    # Weather observations table - real-time atmospheric measurements
    create_table :weather_observations do |t|
      t.references :weather_station, null: false, foreign_key: true, index: true
      t.references :dispersion_scenario, null: true, foreign_key: true, index: true
      
      # Observation metadata
      t.datetime :observed_at, null: false
      t.string :observation_type, null: false # 'current', 'forecast', 'historical'
      t.integer :forecast_hour # Hours ahead for forecasts (null for current)
      t.string :data_source, null: false
      t.decimal :data_confidence, precision: 4, scale: 3 # 0.0-1.0 confidence score
      
      # Basic meteorological parameters
      t.decimal :temperature, precision: 5, scale: 2 # Celsius
      t.decimal :temperature_dewpoint, precision: 5, scale: 2 # Celsius
      t.decimal :relative_humidity, precision: 5, scale: 2 # Percentage
      t.decimal :pressure_station, precision: 7, scale: 2 # hPa
      t.decimal :pressure_sea_level, precision: 7, scale: 2 # hPa
      
      # Wind parameters
      t.decimal :wind_speed, precision: 5, scale: 2 # m/s
      t.decimal :wind_direction, precision: 5, scale: 2 # degrees (0-360)
      t.decimal :wind_gust_speed, precision: 5, scale: 2 # m/s
      t.decimal :wind_speed_10m, precision: 5, scale: 2 # m/s at 10m standard height
      
      # Atmospheric stability parameters
      t.string :pasquill_stability_class, limit: 1 # A, B, C, D, E, F
      t.decimal :richardson_number, precision: 8, scale: 5 # Bulk Richardson number
      t.decimal :monin_obukhov_length, precision: 10, scale: 3 # meters
      t.decimal :friction_velocity, precision: 6, scale: 4 # m/s
      t.decimal :sensible_heat_flux, precision: 8, scale: 3 # W/m²
      
      # Solar radiation and cloud parameters
      t.decimal :solar_radiation, precision: 7, scale: 2 # W/m²
      t.decimal :net_radiation, precision: 7, scale: 2 # W/m²
      t.integer :cloud_cover_total # Percentage (0-100)
      t.integer :cloud_cover_low # Percentage (0-100)
      t.decimal :cloud_base_height, precision: 8, scale: 2 # meters
      t.string :weather_condition # Clear, cloudy, rain, snow, etc.
      
      # Precipitation
      t.decimal :precipitation_rate, precision: 6, scale: 3 # mm/hr
      t.decimal :precipitation_1hr, precision: 6, scale: 3 # mm
      t.decimal :precipitation_24hr, precision: 6, scale: 3 # mm
      
      # Visibility and atmospheric conditions
      t.decimal :visibility, precision: 8, scale: 2 # meters
      t.decimal :mixing_height, precision: 8, scale: 2 # meters
      t.decimal :inversion_height, precision: 8, scale: 2 # meters
      t.boolean :inversion_present, default: false
      
      # Air quality parameters
      t.decimal :turbulence_intensity, precision: 5, scale: 4 # Dimensionless
      t.decimal :sigma_theta, precision: 5, scale: 3 # Wind direction standard deviation (degrees)
      t.decimal :sigma_phi, precision: 5, scale: 3 # Wind elevation standard deviation (degrees)
      
      # Quality flags and metadata
      t.json :quality_flags # Individual parameter quality indicators
      t.json :raw_data # Original data from source for debugging
      t.text :notes # Any special conditions or data quality notes
      
      t.timestamps
    end
    
    # Atmospheric profiles table - vertical atmospheric structure
    create_table :atmospheric_profiles do |t|
      t.references :weather_observation, null: false, foreign_key: true, index: true
      
      # Profile metadata
      t.string :profile_type, null: false # 'radiosonde', 'model', 'estimated'
      t.datetime :profile_time, null: false
      t.decimal :surface_elevation, precision: 8, scale: 2 # meters MSL
      
      # Vertical profile data (JSON arrays for each level)
      t.json :height_levels # Array of heights (meters AGL)
      t.json :temperature_profile # Array of temperatures (Celsius)
      t.json :wind_speed_profile # Array of wind speeds (m/s)
      t.json :wind_direction_profile # Array of wind directions (degrees)
      t.json :humidity_profile # Array of relative humidity (%)
      t.json :pressure_profile # Array of pressure values (hPa)
      
      # Derived atmospheric parameters
      t.decimal :boundary_layer_height, precision: 8, scale: 2 # meters
      t.decimal :capping_inversion_height, precision: 8, scale: 2 # meters
      t.decimal :surface_roughness, precision: 6, scale: 4 # meters
      t.decimal :heat_flux_surface, precision: 8, scale: 3 # W/m²
      t.decimal :momentum_flux_surface, precision: 8, scale: 6 # N/m²
      
      # Stability indicators
      t.decimal :bulk_richardson_number, precision: 8, scale: 5
      t.decimal :gradient_richardson_number, precision: 8, scale: 5
      t.string :atmospheric_stability_category # 'very_unstable', 'unstable', 'neutral', 'stable', 'very_stable'
      
      # Dispersion parameters
      t.decimal :vertical_dispersion_rate, precision: 8, scale: 5 # m²/s
      t.decimal :horizontal_dispersion_rate, precision: 8, scale: 5 # m²/s
      t.decimal :plume_rise_factor, precision: 6, scale: 4 # Dimensionless enhancement factor
      
      t.timestamps
    end
    
    # Weather forecasts table - future atmospheric conditions
    create_table :weather_forecasts do |t|
      t.references :weather_station, null: false, foreign_key: true, index: true
      t.references :dispersion_scenario, null: true, foreign_key: true, index: true
      
      # Forecast metadata
      t.datetime :forecast_issued_at, null: false
      t.datetime :forecast_valid_at, null: false
      t.integer :forecast_hour, null: false # Hours from issue time
      t.string :forecast_model # 'gfs', 'nam', 'hrrr', 'ecmwf', etc.
      t.decimal :forecast_confidence, precision: 4, scale: 3 # 0.0-1.0
      
      # Forecasted parameters (similar structure to observations)
      t.decimal :temperature, precision: 5, scale: 2
      t.decimal :temperature_min, precision: 5, scale: 2 # Daily min
      t.decimal :temperature_max, precision: 5, scale: 2 # Daily max
      t.decimal :wind_speed, precision: 5, scale: 2
      t.decimal :wind_direction, precision: 5, scale: 2
      t.decimal :wind_gust_speed, precision: 5, scale: 2
      
      # Stability forecast
      t.string :predicted_stability_class, limit: 1
      t.decimal :predicted_mixing_height, precision: 8, scale: 2
      t.integer :cloud_cover_forecast
      t.decimal :precipitation_probability, precision: 4, scale: 2 # 0-100%
      t.decimal :precipitation_amount, precision: 6, scale: 3 # mm
      
      # Extended forecast parameters
      t.json :hourly_temperature # 24-hour temperature array
      t.json :hourly_wind_speed # 24-hour wind speed array
      t.json :hourly_wind_direction # 24-hour wind direction array
      t.json :hourly_stability_class # 24-hour stability array
      
      t.timestamps
    end
    
    # Location weather cache - for quick weather lookup by coordinates
    create_table :location_weather_cache do |t|
      # Location identification
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.string :location_hash, null: false, index: { unique: true } # Geohash for quick lookup
      
      # Nearest weather stations
      t.references :primary_weather_station, null: false, foreign_key: { to_table: :weather_stations }
      t.references :secondary_weather_station, null: true, foreign_key: { to_table: :weather_stations }
      t.references :tertiary_weather_station, null: true, foreign_key: { to_table: :weather_stations }
      
      # Interpolation weights
      t.decimal :primary_weight, precision: 4, scale: 3, default: 1.0
      t.decimal :secondary_weight, precision: 4, scale: 3, default: 0.0
      t.decimal :tertiary_weight, precision: 4, scale: 3, default: 0.0
      
      # Distance to stations (km)
      t.decimal :primary_distance, precision: 8, scale: 3
      t.decimal :secondary_distance, precision: 8, scale: 3
      t.decimal :tertiary_distance, precision: 8, scale: 3
      
      # Cache metadata
      t.datetime :last_updated_at
      t.integer :update_frequency # Minutes between updates
      t.boolean :auto_update, default: true
      
      t.timestamps
    end
    
    # Add indexes for efficient querying
    add_index :weather_stations, [:latitude, :longitude], name: 'index_weather_stations_on_coordinates'
    add_index :weather_stations, [:active, :station_type], name: 'index_weather_stations_on_active_type'
    add_index :weather_stations, [:data_source, :last_observation_at], name: 'index_weather_stations_on_source_observation'
    
    add_index :weather_observations, [:observed_at, :observation_type], name: 'index_weather_observations_on_time_type'
    add_index :weather_observations, [:weather_station_id, :observed_at], name: 'index_weather_observations_on_station_time'
    add_index :weather_observations, [:pasquill_stability_class, :observed_at], name: 'index_weather_observations_on_stability_time'
    add_index :weather_observations, [:dispersion_scenario_id, :observed_at], name: 'index_weather_observations_on_scenario_time'
    
    add_index :atmospheric_profiles, [:profile_time, :profile_type], name: 'index_atmospheric_profiles_on_time_type'
    add_index :atmospheric_profiles, [:weather_observation_id, :profile_time], name: 'index_atmospheric_profiles_on_observation_time'
    
    add_index :weather_forecasts, [:forecast_valid_at, :forecast_hour], name: 'index_weather_forecasts_on_valid_hour'
    add_index :weather_forecasts, [:weather_station_id, :forecast_valid_at], name: 'index_weather_forecasts_on_station_valid'
    add_index :weather_forecasts, [:dispersion_scenario_id, :forecast_valid_at], name: 'index_weather_forecasts_on_scenario_valid'
    
    add_index :location_weather_cache, [:latitude, :longitude], name: 'index_location_weather_cache_on_coordinates'
    add_index :location_weather_cache, [:last_updated_at, :auto_update], name: 'index_location_weather_cache_on_update'
  end
end
