# Detailed plume calculation results at specific spatial and temporal points
# Stores concentration, dispersion parameters, and atmospheric conditions
class PlumeCalculation < ApplicationRecord
  belongs_to :atmospheric_dispersion
  
  # Validations
  validates :downwind_distance, :crosswind_distance, :vertical_distance,
            :time_step, :elapsed_time, :ground_level_concentration,
            presence: true, numericality: true
  validates :time_step, numericality: { greater_than: 0 }
  validates :elapsed_time, numericality: { greater_than_or_equal_to: 0 }
  validates :ground_level_concentration, numericality: { greater_than_or_equal_to: 0 }
  validates :concentration_units, inclusion: { in: %w[mg/m3 ppm ug/m3 g/m3] }
  
  # Scopes for spatial and temporal filtering
  scope :at_time_step, ->(step) { where(time_step: step) }
  scope :at_elapsed_time, ->(time) { where(elapsed_time: time) }
  scope :within_distance, ->(max_dist) { where('downwind_distance <= ?', max_dist) }
  scope :above_concentration, ->(threshold) { where('ground_level_concentration >= ?', threshold) }
  scope :centerline, -> { where(crosswind_distance: 0) }
  scope :ground_level, -> { where(vertical_distance: 0) }
  
  # Delegate to atmospheric dispersion and scenario
  delegate :dispersion_scenario, to: :atmospheric_dispersion
  delegate :chemical, to: :atmospheric_dispersion
  delegate :pasquill_stability_class, to: :atmospheric_dispersion
  
  # Spatial calculations
  def distance_from_source
    Math.sqrt(downwind_distance**2 + crosswind_distance**2)
  end
  
  def angle_from_source
    Math.atan2(crosswind_distance, downwind_distance) * 180.0 / Math::PI
  end
  
  # Convert coordinates to lat/lon if not already stored
  def calculated_latitude
    return latitude if latitude.present?
    
    # Convert from local coordinates using scenario location
    scenario = dispersion_scenario
    scenario.latitude + (crosswind_distance / 111320.0)
  end
  
  def calculated_longitude
    return longitude if longitude.present?
    
    scenario = dispersion_scenario
    cos_lat = Math.cos(scenario.latitude * Math::PI / 180.0)
    scenario.longitude + (downwind_distance / (111320.0 * cos_lat))
  end
  
  # Concentration unit conversions
  def concentration_in_ppm
    return ground_level_concentration if concentration_units == 'ppm'
    
    # Convert from mg/m3 to ppm using molecular weight
    mol_weight = chemical.molecular_weight
    return nil unless mol_weight && mol_weight > 0
    
    # ppm = (mg/m3) * 24.45 / MW at STP
    temperature = air_temperature || 298.15 # K
    pressure = air_pressure || 101325.0 # Pa
    
    # Ideal gas law conversion: ppm = (C_mg/m3 * R * T) / (MW * P)
    r_constant = 8.314 # J/(mol·K)
    (ground_level_concentration * r_constant * temperature) / (mol_weight * pressure / 1000.0)
  end
  
  def concentration_in_mg_m3
    return ground_level_concentration if concentration_units == 'mg/m3'
    
    case concentration_units
    when 'ppm'
      # Convert ppm to mg/m3
      mol_weight = chemical.molecular_weight
      return nil unless mol_weight && mol_weight > 0
      
      temperature = air_temperature || 298.15
      pressure = air_pressure || 101325.0
      
      (ground_level_concentration * mol_weight * pressure) / (8.314 * temperature * 1000.0)
    when 'ug/m3'
      ground_level_concentration / 1000.0
    when 'g/m3'
      ground_level_concentration * 1000.0
    else
      ground_level_concentration
    end
  end
  
  # Plume dimensions and characteristics
  def plume_half_width
    sigma_y * 1.177 # Distance to half-maximum concentration
  end
  
  def plume_half_depth
    sigma_z * 1.177
  end
  
  def is_centerline?
    crosswind_distance.abs < 0.1 # Within 0.1 m of centerline
  end
  
  def is_ground_level?
    vertical_distance.abs < 0.1 # Within 0.1 m of ground
  end
  
  # Calculate relative concentration (fraction of centerline maximum)
  def relative_concentration
    return 1.0 if centerline_concentration.nil? || centerline_concentration == 0
    
    ground_level_concentration / centerline_concentration
  end
  
  # Atmospheric stability indicators
  def atmospheric_conditions
    {
      stability_class: pasquill_stability_class,
      wind_speed: local_wind_speed,
      air_density: air_density,
      mixing_height_effect: mixing_height_effect,
      dilution_factor: dilution_factor
    }
  end
  
  # Heavy gas specific properties
  def heavy_gas_properties
    return {} unless atmospheric_dispersion.dispersion_model.in?(%w[heavy_gas dense_gas])
    
    {
      cloud_radius: cloud_radius,
      cloud_density: cloud_density,
      entrainment_rate: entrainment_rate,
      cloud_temperature: cloud_temperature
    }
  end
  
  # Transport and fate calculations
  def arrival_time_at_receptor
    return arrival_time if arrival_time.present?
    
    # Estimate based on wind speed and distance
    distance = distance_from_source
    wind_speed = local_wind_speed || atmospheric_dispersion.wind_speed_at_release
    
    distance / wind_speed if wind_speed > 0
  end
  
  def passage_duration_at_receptor
    return passage_duration if passage_duration.present?
    
    # Estimate based on plume width and wind speed
    plume_width_at_point = 4.0 * sigma_y # ±2σ
    wind_speed = local_wind_speed || atmospheric_dispersion.wind_speed_at_release
    
    plume_width_at_point / wind_speed if wind_speed > 0
  end
  
  # Data quality and validation
  def calculation_quality
    warnings = []
    
    # Check for reasonable values
    warnings << "Very high concentration" if ground_level_concentration > 1000.0
    warnings << "Unrealistic dispersion coefficient" if sigma_y && sigma_y > downwind_distance
    warnings << "Low wind speed extrapolation" if local_wind_speed && local_wind_speed < 0.5
    warnings << "High uncertainty" if atmospheric_dispersion.calculation_uncertainty && 
                                     atmospheric_dispersion.calculation_uncertainty > 0.5
    
    # Check for edge effects
    warnings << "Near calculation boundary" if downwind_distance > atmospheric_dispersion.max_downwind_distance * 0.9
    warnings << "High crosswind distance" if crosswind_distance.abs > atmospheric_dispersion.max_crosswind_distance * 0.8
    
    {
      quality_score: warnings.empty? ? 1.0 : [0.1, 1.0 - warnings.length * 0.2].max,
      warnings: warnings,
      data_completeness: calculate_data_completeness
    }
  end
  
  # Export for visualization or analysis
  def to_visualization_hash
    {
      coordinates: {
        x: downwind_distance,
        y: crosswind_distance,
        z: vertical_distance,
        lat: calculated_latitude,
        lon: calculated_longitude
      },
      concentration: {
        value: ground_level_concentration,
        units: concentration_units,
        ppm: concentration_in_ppm,
        mg_m3: concentration_in_mg_m3
      },
      plume: {
        sigma_y: sigma_y,
        sigma_z: sigma_z,
        height: plume_height,
        width: plume_width,
        depth: plume_depth
      },
      time: {
        step: time_step,
        elapsed: elapsed_time,
        arrival: arrival_time_at_receptor,
        duration: passage_duration_at_receptor
      },
      atmospheric: atmospheric_conditions,
      quality: calculation_quality
    }
  end
  
  private
  
  def air_temperature
    atmospheric_dispersion.dispersion_scenario.ambient_temperature&.+(273.15)
  end
  
  def air_pressure
    atmospheric_dispersion.dispersion_scenario.ambient_pressure || 101325.0
  end
  
  def calculate_data_completeness
    required_fields = %w[ground_level_concentration sigma_y sigma_z local_wind_speed]
    present_fields = required_fields.count { |field| send(field).present? }
    
    present_fields.to_f / required_fields.length
  end
end