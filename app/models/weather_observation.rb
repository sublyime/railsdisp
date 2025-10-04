# Weather Observation model for real-time atmospheric measurements
# Stores comprehensive meteorological data with Pasquill stability classification
class WeatherObservation < ApplicationRecord
  belongs_to :weather_station
  belongs_to :dispersion_scenario, optional: true
  has_many :atmospheric_profiles, dependent: :destroy
  
  # Delegate station information for convenience
  delegate :latitude, :longitude, :elevation, :station_id, :station_type, to: :weather_station
  
  # Validations
  validates :observed_at, presence: true
  validates :observation_type, presence: true, inclusion: { 
    in: %w[current forecast historical interpolated synthetic] 
  }
  validates :data_source, presence: true
  validates :data_confidence, numericality: { in: 0.0..1.0 }, allow_nil: true
  validates :pasquill_stability_class, inclusion: { in: %w[A B C D E F] }, allow_nil: true
  validates :forecast_hour, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Meteorological parameter validations
  validates :temperature, numericality: { greater_than: -100, less_than: 60 }, allow_nil: true
  validates :temperature_dewpoint, numericality: { greater_than: -100, less_than: 60 }, allow_nil: true
  validates :relative_humidity, numericality: { in: 0..100 }, allow_nil: true
  validates :wind_speed, numericality: { greater_than_or_equal_to: 0, less_than: 100 }, allow_nil: true
  validates :wind_direction, numericality: { in: 0..360 }, allow_nil: true
  validates :pressure_sea_level, numericality: { greater_than: 800, less_than: 1100 }, allow_nil: true
  validates :cloud_cover_total, numericality: { in: 0..100 }, allow_nil: true
  validates :visibility, numericality: { greater_than: 0 }, allow_nil: true
  validates :solar_radiation, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes for efficient querying
  scope :current, -> { where(observation_type: 'current') }
  scope :forecast, -> { where(observation_type: 'forecast') }
  scope :historical, -> { where(observation_type: 'historical') }
  scope :recent, -> { where('observed_at > ?', 2.hours.ago) }
  scope :today, -> { where('observed_at > ?', 24.hours.ago) }
  scope :by_stability, ->(stability_class) { where(pasquill_stability_class: stability_class) }
  scope :stable_conditions, -> { where(pasquill_stability_class: ['E', 'F']) }
  scope :unstable_conditions, -> { where(pasquill_stability_class: ['A', 'B', 'C']) }
  scope :neutral_conditions, -> { where(pasquill_stability_class: 'D') }
  scope :high_confidence, -> { where('data_confidence > ?', 0.8) }
  scope :with_wind_data, -> { where.not(wind_speed: nil, wind_direction: nil) }
  scope :with_stability_data, -> { where.not(pasquill_stability_class: nil) }
  
  # Temporal scopes
  scope :for_time_period, ->(start_time, end_time) { 
    where(observed_at: start_time..end_time) 
  }
  scope :for_scenario, ->(scenario) { where(dispersion_scenario: scenario) }
  scope :for_location, ->(lat, lon, radius_km) {
    joins(:weather_station).merge(
      WeatherStation.within_radius(lat, lon, radius_km)
    )
  }
  
  # JSON field accessors with defaults
  def quality_flags
    self[:quality_flags] || {}
  end
  
  def raw_data
    self[:raw_data] || {}
  end
  
  # Check if observation has required parameters for dispersion modeling
  def has_required_parameters?
    temperature.present? && 
    wind_speed.present? && 
    wind_direction.present? &&
    (pasquill_stability_class.present? || can_calculate_stability?)
  end
  
  # Check if we can calculate stability from available parameters
  def can_calculate_stability?
    wind_speed.present? && 
    (solar_radiation.present? || cloud_cover_total.present?) &&
    observed_at.present?
  end
  
  # Calculate Pasquill stability class if not provided
  def calculate_pasquill_stability_class!
    return pasquill_stability_class if pasquill_stability_class.present?
    return nil unless can_calculate_stability?
    
    stability = determine_pasquill_stability_class
    update!(pasquill_stability_class: stability) if stability
    stability
  end
  
  # Determine Pasquill stability class using Turner method
  def determine_pasquill_stability_class
    return nil unless wind_speed.present? && observed_at.present?
    
    # Get solar angle and net radiation conditions
    solar_conditions = determine_solar_conditions
    return nil unless solar_conditions
    
    wind_speed_ms = wind_speed
    
    # Turner (1964) method for stability classification
    case solar_conditions
    when :strong_insolation
      case wind_speed_ms
      when 0...2 then 'A'
      when 2...3 then 'A'
      when 3...4 then 'B'
      when 4...6 then 'C'
      else 'D'
      end
    when :moderate_insolation
      case wind_speed_ms
      when 0...2 then 'A'
      when 2...3 then 'B'
      when 3...5 then 'B'
      when 5...6 then 'C'
      else 'D'
      end
    when :slight_insolation
      case wind_speed_ms
      when 0...2 then 'B'
      when 2...5 then 'C'
      else 'D'
      end
    when :overcast_day, :neutral
      'D'
    when :clear_night
      case wind_speed_ms
      when 0...2 then 'F'
      when 2...3 then 'F'
      when 3...5 then 'E'
      else 'D'
      end
    when :partly_cloudy_night
      case wind_speed_ms
      when 0...2 then 'E'
      when 2...5 then 'E'
      else 'D'
      end
    when :overcast_night
      'D'
    else
      'D' # Default to neutral
    end
  end
  
  # Determine solar conditions based on time, cloud cover, and solar radiation
  def determine_solar_conditions
    return nil unless observed_at.present?
    
    # Check if it's day or night
    is_daytime = daytime?
    
    if is_daytime
      # Daytime conditions
      if solar_radiation.present?
        case solar_radiation
        when 0...200 then :slight_insolation
        when 200...600 then :moderate_insolation
        else :strong_insolation
        end
      elsif cloud_cover_total.present?
        case cloud_cover_total
        when 0...30 then :strong_insolation
        when 30...70 then :moderate_insolation
        when 70...95 then :slight_insolation
        else :overcast_day
        end
      else
        # Estimate based on time of day
        hour = observed_at.hour
        case hour
        when 10..14 then :strong_insolation
        when 8..16 then :moderate_insolation
        else :slight_insolation
        end
      end
    else
      # Nighttime conditions
      if cloud_cover_total.present?
        case cloud_cover_total
        when 0...40 then :clear_night
        when 40...80 then :partly_cloudy_night
        else :overcast_night
        end
      else
        :clear_night # Default assumption
      end
    end
  end
  
  # Check if observation time is during daytime
  def daytime?
    return nil unless observed_at.present?
    
    # Simplified: consider 6 AM to 6 PM as daytime
    # In practice, would use solar angle calculation
    hour = observed_at.hour
    hour.between?(6, 17)
  end
  
  # Calculate atmospheric stability parameters
  def calculate_stability_parameters!
    return unless has_required_parameters?
    
    # Calculate Richardson number (bulk)
    if temperature.present? && temperature_dewpoint.present?
      calc_richardson = calculate_bulk_richardson_number
      update!(richardson_number: calc_richardson) if calc_richardson
    end
    
    # Calculate Monin-Obukhov length
    if friction_velocity.present? && sensible_heat_flux.present?
      calc_mo_length = calculate_monin_obukhov_length
      update!(monin_obukhov_length: calc_mo_length) if calc_mo_length
    end
    
    # Estimate friction velocity from wind speed
    unless friction_velocity.present?
      calc_ustar = estimate_friction_velocity
      update!(friction_velocity: calc_ustar) if calc_ustar
    end
    
    # Update stability class if not present
    calculate_pasquill_stability_class! unless pasquill_stability_class.present?
  end
  
  # Calculate bulk Richardson number
  def calculate_bulk_richardson_number
    return nil unless temperature.present? && wind_speed.present?
    
    # Simplified calculation using surface temperature and wind
    # Ri = (g / T) * (ΔT / Δz) / (Δu / Δz)²
    # Assuming standard 10m wind measurement and surface temperature difference
    
    g = 9.81 # Gravity
    t_kelvin = temperature + 273.15
    delta_z = 10.0 # 10 meter measurement height
    
    # Estimate temperature gradient (simplified)
    # Positive for stable, negative for unstable
    stability_factor = case pasquill_stability_class
                      when 'A' then -0.02 # Very unstable
                      when 'B' then -0.015 # Moderately unstable
                      when 'C' then -0.01 # Slightly unstable
                      when 'D' then 0.0 # Neutral
                      when 'E' then 0.01 # Slightly stable
                      when 'F' then 0.02 # Moderately stable
                      else 0.0
                      end
    
    delta_t = stability_factor * delta_z
    
    return 0 if wind_speed < 0.1 # Avoid division by zero
    
    (g / t_kelvin) * (delta_t / delta_z) / (wind_speed / delta_z)**2
  end
  
  # Calculate Monin-Obukhov length
  def calculate_monin_obukhov_length
    return nil unless friction_velocity.present? && temperature.present?
    
    # L = -ρ * cp * T * u*³ / (κ * g * H)
    # where H is sensible heat flux
    
    rho = 1.225 # Air density kg/m³ (at sea level)
    cp = 1004.0 # Specific heat J/kg/K
    kappa = 0.4 # Von Kármán constant
    g = 9.81 # Gravity
    t_kelvin = temperature + 273.15
    
    # Estimate heat flux if not available
    heat_flux = sensible_heat_flux || estimate_sensible_heat_flux
    return nil unless heat_flux
    
    return Float::INFINITY if heat_flux.abs < 0.1 # Nearly neutral
    
    -(rho * cp * t_kelvin * friction_velocity**3) / (kappa * g * heat_flux)
  end
  
  # Estimate friction velocity from wind speed
  def estimate_friction_velocity
    return nil unless wind_speed.present?
    
    # u* = u * κ / ln(z/z0)
    # where z is measurement height, z0 is roughness length
    
    kappa = 0.4 # Von Kármán constant
    z = 10.0 # Assumed 10m measurement height
    z0 = 0.1 # Assumed roughness length for typical terrain
    
    wind_speed * kappa / Math.log(z / z0)
  end
  
  # Estimate sensible heat flux
  def estimate_sensible_heat_flux
    return nil unless temperature.present? && daytime?.present?
    
    # Simplified estimation based on stability class and solar conditions
    if daytime?
      case pasquill_stability_class
      when 'A' then 300 # Strong heating
      when 'B' then 200 # Moderate heating
      when 'C' then 100 # Slight heating
      when 'D' then 0 # Neutral
      when 'E' then -50 # Slight cooling (rare during day)
      when 'F' then -100 # Moderate cooling (rare during day)
      else 50 # Default slight heating
      end
    else
      # Nighttime - typically cooling
      case pasquill_stability_class
      when 'A', 'B', 'C' then 0 # Neutral (rare at night)
      when 'D' then 0 # Neutral
      when 'E' then -50 # Slight cooling
      when 'F' then -100 # Strong cooling
      else -25 # Default slight cooling
      end
    end
  end
  
  # Calculate dispersion parameters for atmospheric models
  def calculate_dispersion_parameters
    return {} unless pasquill_stability_class.present? && wind_speed.present?
    
    stability = pasquill_stability_class
    
    # Pasquill-Gifford dispersion coefficients
    # σy = ax^b and σz = cx^d where x is downwind distance
    
    # Horizontal dispersion parameters (σy)
    sigma_y_params = case stability
                    when 'A' then { a: 0.22, b: 0.0001 }
                    when 'B' then { a: 0.16, b: 0.0001 }
                    when 'C' then { a: 0.11, b: 0.0001 }
                    when 'D' then { a: 0.08, b: 0.0001 }
                    when 'E' then { a: 0.06, b: 0.0001 }
                    when 'F' then { a: 0.04, b: 0.0001 }
                    end
    
    # Vertical dispersion parameters (σz)
    sigma_z_params = case stability
                    when 'A' then { c: 0.20, d: 0.0 }
                    when 'B' then { c: 0.12, d: 0.0 }
                    when 'C' then { c: 0.08, d: 0.0002 }
                    when 'D' then { c: 0.06, d: 0.0015 }
                    when 'E' then { c: 0.03, d: 0.0003 }
                    when 'F' then { c: 0.016, d: 0.0003 }
                    end
    
    # Plume rise parameters
    plume_rise_factor = case stability
                       when 'A', 'B' then 1.5 # Enhanced mixing
                       when 'C' then 1.2
                       when 'D' then 1.0 # Neutral
                       when 'E' then 0.8 # Reduced mixing
                       when 'F' then 0.6 # Strong suppression
                       end
    
    {
      stability_class: stability,
      sigma_y_coefficients: sigma_y_params,
      sigma_z_coefficients: sigma_z_params,
      plume_rise_factor: plume_rise_factor,
      wind_speed: wind_speed,
      wind_direction: wind_direction,
      mixing_height: mixing_height || estimate_mixing_height,
      friction_velocity: friction_velocity || estimate_friction_velocity,
      monin_obukhov_length: monin_obukhov_length || calculate_monin_obukhov_length
    }
  end
  
  # Estimate mixing height based on stability conditions
  def estimate_mixing_height
    return mixing_height if mixing_height.present?
    
    # Estimate based on stability class and time of day
    base_height = if daytime?
                   case pasquill_stability_class
                   when 'A' then 2000 # Very unstable - high mixing
                   when 'B' then 1500 # Moderately unstable
                   when 'C' then 1000 # Slightly unstable
                   when 'D' then 800 # Neutral
                   when 'E' then 400 # Slightly stable
                   when 'F' then 200 # Very stable - low mixing
                   else 800
                   end
                 else
                   # Nighttime - generally lower mixing heights
                   case pasquill_stability_class
                   when 'A', 'B', 'C' then 600 # Rare unstable at night
                   when 'D' then 400 # Neutral
                   when 'E' then 200 # Slightly stable
                   when 'F' then 100 # Very stable
                   else 300
                   end
                 end
    
    # Adjust for wind speed (higher winds increase mixing)
    wind_factor = [1.0 + (wind_speed || 5.0) / 20.0, 2.0].min
    base_height * wind_factor
  end
  
  # Generate weather summary for display
  def weather_summary
    {
      basic_conditions: {
        temperature: temperature&.round(1),
        temperature_dewpoint: temperature_dewpoint&.round(1),
        relative_humidity: relative_humidity&.round,
        pressure: pressure_sea_level&.round(1),
        weather_condition: weather_condition
      },
      wind_conditions: {
        speed: wind_speed&.round(1),
        direction: wind_direction&.round,
        gust_speed: wind_gust_speed&.round(1),
        speed_10m: wind_speed_10m&.round(1)
      },
      atmospheric_stability: {
        pasquill_class: pasquill_stability_class,
        richardson_number: richardson_number&.round(5),
        monin_obukhov_length: monin_obukhov_length&.round(1),
        friction_velocity: friction_velocity&.round(3),
        mixing_height: mixing_height || estimate_mixing_height
      },
      cloud_and_radiation: {
        cloud_cover_total: cloud_cover_total,
        cloud_cover_low: cloud_cover_low,
        solar_radiation: solar_radiation&.round(1),
        visibility: visibility&.round
      },
      data_quality: {
        observation_type: observation_type,
        data_source: data_source,
        confidence: data_confidence&.round(3),
        observed_at: observed_at
      }
    }
  end
  
  # Export observation for dispersion modeling
  def to_dispersion_input
    calculate_stability_parameters! unless pasquill_stability_class.present?
    
    {
      location: {
        latitude: latitude,
        longitude: longitude,
        elevation: elevation
      },
      meteorology: {
        wind_speed: wind_speed,
        wind_direction: wind_direction,
        temperature: temperature,
        pressure: pressure_sea_level,
        humidity: relative_humidity,
        stability_class: pasquill_stability_class
      },
      atmospheric_parameters: calculate_dispersion_parameters,
      observation_metadata: {
        observed_at: observed_at,
        data_source: data_source,
        confidence: data_confidence,
        station_id: station_id
      }
    }
  end
  
  # Check atmospheric conditions suitable for chemical dispersion
  def suitable_for_dispersion_modeling?
    has_required_parameters? &&
    data_confidence.present? && data_confidence >= 0.6 &&
    observed_at > 6.hours.ago &&
    wind_speed.present? && wind_speed >= 0.5 && # Minimum wind for meaningful dispersion
    pasquill_stability_class.present?
  end
  
  # Calculate atmospheric turbulence characteristics
  def calculate_turbulence_characteristics
    return {} unless wind_speed.present? && pasquill_stability_class.present?
    
    # Turbulence intensity estimates by stability class
    turbulence_intensity_est = case pasquill_stability_class
                              when 'A' then 0.25 # Very turbulent
                              when 'B' then 0.20 # Moderately turbulent
                              when 'C' then 0.15 # Slightly turbulent
                              when 'D' then 0.10 # Neutral
                              when 'E' then 0.08 # Slightly stable
                              when 'F' then 0.05 # Very stable, low turbulence
                              end
    
    # Wind direction variability (standard deviation)
    sigma_theta_est = case pasquill_stability_class
                     when 'A' then 25.0 # High variability
                     when 'B' then 20.0
                     when 'C' then 15.0
                     when 'D' then 10.0
                     when 'E' then 5.0
                     when 'F' then 2.5 # Low variability
                     end
    
    {
      turbulence_intensity: turbulence_intensity || turbulence_intensity_est,
      sigma_theta: sigma_theta || sigma_theta_est,
      sigma_phi: sigma_phi || (sigma_theta_est * 0.6), # Vertical angle variability
      eddy_diffusivity: calculate_eddy_diffusivity,
      lagrangian_time_scale: calculate_lagrangian_time_scale
    }
  end
  
  # Calculate eddy diffusivity for turbulent mixing
  def calculate_eddy_diffusivity
    return nil unless wind_speed.present? && friction_velocity.present?
    
    # K = u* * κ * z / φ where φ is stability function
    kappa = 0.4
    z = 10.0 # Reference height
    
    phi = case pasquill_stability_class
          when 'A' then 0.5 # Unstable - enhanced mixing
          when 'B' then 0.7
          when 'C' then 0.9
          when 'D' then 1.0 # Neutral
          when 'E' then 1.5 # Stable - reduced mixing
          when 'F' then 2.0
          else 1.0
          end
    
    friction_velocity * kappa * z / phi
  end
  
  # Calculate Lagrangian time scale for dispersion
  def calculate_lagrangian_time_scale
    return nil unless wind_speed.present?
    
    # TL ≈ mixing height / wind speed (simplified)
    mixing_ht = mixing_height || estimate_mixing_height
    mixing_ht / wind_speed
  end
  
  # Generate atmospheric stability report
  def generate_stability_report
    calculate_stability_parameters!
    
    {
      observation_info: {
        station_id: station_id,
        observed_at: observed_at,
        location: [latitude, longitude],
        elevation: elevation
      },
      meteorological_parameters: {
        temperature: temperature,
        wind_speed: wind_speed,
        wind_direction: wind_direction,
        pressure: pressure_sea_level,
        humidity: relative_humidity,
        cloud_cover: cloud_cover_total,
        solar_radiation: solar_radiation
      },
      stability_classification: {
        pasquill_class: pasquill_stability_class,
        stability_description: stability_description,
        richardson_number: richardson_number,
        monin_obukhov_length: monin_obukhov_length,
        friction_velocity: friction_velocity
      },
      dispersion_conditions: {
        mixing_height: mixing_height || estimate_mixing_height,
        turbulence_characteristics: calculate_turbulence_characteristics,
        dispersion_parameters: calculate_dispersion_parameters,
        suitable_for_modeling: suitable_for_dispersion_modeling?
      },
      data_quality: {
        source: data_source,
        confidence: data_confidence,
        quality_flags: quality_flags,
        completeness: calculate_data_completeness
      }
    }
  end
  
  private
  
  # Get stability description
  def stability_description
    case pasquill_stability_class
    when 'A' then 'Very Unstable - Strong convection, high turbulence'
    when 'B' then 'Moderately Unstable - Moderate convection'
    when 'C' then 'Slightly Unstable - Weak convection'
    when 'D' then 'Neutral - Mechanical turbulence dominates'
    when 'E' then 'Slightly Stable - Weak inversion, limited mixing'
    when 'F' then 'Moderately Stable - Strong inversion, very limited mixing'
    else 'Unknown'
    end
  end
  
  # Calculate data completeness score
  def calculate_data_completeness
    required_params = %w[temperature wind_speed wind_direction]
    optional_params = %w[pressure_sea_level relative_humidity cloud_cover_total]
    
    required_score = required_params.count { |param| send(param).present? } / required_params.count.to_f
    optional_score = optional_params.count { |param| send(param).present? } / optional_params.count.to_f
    
    # Weight required parameters more heavily
    (required_score * 0.7 + optional_score * 0.3) * 100
  end
end