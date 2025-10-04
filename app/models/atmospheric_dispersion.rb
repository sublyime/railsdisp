# Atmospheric dispersion model implementing ALOHA Chapter 4 algorithms
# Handles both Gaussian and Heavy Gas dispersion models with Pasquill stability classification
class AtmosphericDispersion < ApplicationRecord
  belongs_to :dispersion_scenario
  has_many :plume_calculations, dependent: :destroy
  has_many :concentration_contours, dependent: :destroy
  has_many :receptor_calculations, dependent: :destroy
  
  # Model validation
  validates :dispersion_model, inclusion: { in: %w[gaussian heavy_gas dense_gas] }
  validates :pasquill_stability_class, inclusion: { in: %w[A B C D E F] }
  validates :wind_speed_at_release, :wind_speed_at_10m, :effective_release_height, 
            presence: true, numericality: { greater_than: 0 }
  validates :calculation_status, inclusion: { in: %w[pending calculating completed failed] }
  
  # Delegate to scenario and chemical for convenience
  delegate :chemical, to: :dispersion_scenario
  delegate :source_details, to: :dispersion_scenario
  delegate :release_calculations, to: :dispersion_scenario
  
  # Scopes for filtering
  scope :by_model, ->(model) { where(dispersion_model: model) }
  scope :by_stability, ->(stability) { where(pasquill_stability_class: stability) }
  scope :completed, -> { where(calculation_status: 'completed') }
  scope :failed, -> { where(calculation_status: 'failed') }
  
  # Main calculation methods
  def calculate_dispersion!
    update!(calculation_status: 'calculating', last_calculated_at: Time.current)
    
    begin
      case dispersion_model
      when 'gaussian'
        calculate_gaussian_dispersion!
      when 'heavy_gas', 'dense_gas'
        calculate_heavy_gas_dispersion!
      end
      
      update!(calculation_status: 'completed')
    rescue StandardError => e
      update!(
        calculation_status: 'failed',
        calculation_warnings: "Calculation failed: #{e.message}"
      )
      raise
    end
  end
  
  # Gaussian dispersion model (ALOHA Chapter 4.1)
  def calculate_gaussian_dispersion!
    validate_gaussian_parameters!
    
    # Clear existing calculations
    plume_calculations.destroy_all
    concentration_contours.destroy_all
    receptor_calculations.destroy_all
    
    # Calculate dispersion coefficients
    calculate_dispersion_coefficients!
    
    # Generate spatial grid
    grid_points = generate_spatial_grid
    
    # Calculate concentrations for each time step
    (1..time_steps).each do |step|
      elapsed = step * calculation_time_step
      
      grid_points.each do |point|
        concentration = gaussian_concentration(
          point[:x], point[:y], point[:z], elapsed
        )
        
        next if concentration < 1e-12 # Skip negligible concentrations
        
        create_plume_calculation(point, step, elapsed, concentration)
      end
      
      # Generate contours for this time step
      generate_contours_for_timestep(step, elapsed)
    end
    
    # Calculate receptor impacts
    calculate_receptor_impacts!
  end
  
  # Heavy gas dispersion model (ALOHA Chapter 4.2)
  def calculate_heavy_gas_dispersion!
    validate_heavy_gas_parameters!
    
    # Clear existing calculations
    plume_calculations.destroy_all
    concentration_contours.destroy_all
    receptor_calculations.destroy_all
    
    # Calculate initial cloud parameters
    calculate_initial_cloud_properties!
    
    # Generate spatial grid for heavy gas model
    grid_points = generate_heavy_gas_grid
    
    # Time-stepping for heavy gas evolution
    (1..time_steps).each do |step|
      elapsed = step * calculation_time_step
      
      grid_points.each do |point|
        concentration = heavy_gas_concentration(
          point[:x], point[:y], point[:z], elapsed
        )
        
        next if concentration < 1e-12
        
        create_plume_calculation(point, step, elapsed, concentration)
      end
      
      # Update cloud properties for next time step
      update_cloud_properties!(elapsed)
      
      # Generate contours
      generate_contours_for_timestep(step, elapsed)
    end
    
    # Calculate receptor impacts
    calculate_receptor_impacts!
  end
  
  # Gaussian concentration calculation (Equation 4.1-4.3 in ALOHA manual)
  def gaussian_concentration(x, y, z, time)
    return 0.0 if x <= 0 # No upwind concentrations
    
    # Get release rate at this time
    release_rate = interpolate_release_rate(time)
    return 0.0 if release_rate <= 0
    
    # Calculate dispersion parameters
    sigma_y = calculate_sigma_y(x)
    sigma_z = calculate_sigma_z(x)
    
    # Effective release height with plume rise
    h_eff = effective_release_height + calculate_plume_rise(x)
    
    # Wind speed at release height
    u = wind_speed_at_height(h_eff)
    
    # Gaussian dispersion equation
    # C = (Q / (2π * σy * σz * u)) * exp(-y²/(2σy²)) * [exp(-(z-h)²/(2σz²)) + exp(-(z+h)²/(2σz²))]
    
    lateral_term = Math.exp(-0.5 * (y / sigma_y)**2)
    
    vertical_term = Math.exp(-0.5 * ((z - h_eff) / sigma_z)**2) +
                   Math.exp(-0.5 * ((z + h_eff) / sigma_z)**2)
    
    # Apply mixing height reflection if needed
    if boundary_layer_height && boundary_layer_height > 0
      vertical_term = apply_mixing_height_reflection(vertical_term, z, h_eff, sigma_z)
    end
    
    concentration = (release_rate / (2 * Math::PI * sigma_y * sigma_z * u)) *
                   lateral_term * vertical_term
    
    # Apply depletion and decay factors
    concentration *= calculate_depletion_factor(x, time) if include_depletion
    concentration *= calculate_decay_factor(time) if include_decay
    
    concentration
  end
  
  # Heavy gas concentration calculation (Box model approach, ALOHA Chapter 4.2)
  def heavy_gas_concentration(x, y, z, time)
    return 0.0 if x <= 0
    
    # Get current cloud properties
    cloud_props = interpolate_cloud_properties(time)
    return 0.0 if cloud_props[:mass] <= 0
    
    # Check if point is within cloud boundaries
    distance_from_center = Math.sqrt(x**2 + y**2)
    
    if distance_from_center <= cloud_props[:radius] && z <= cloud_props[:height]
      # Inside cloud - uniform concentration
      cloud_volume = Math::PI * cloud_props[:radius]**2 * cloud_props[:height]
      concentration = cloud_props[:mass] / (cloud_volume * cloud_props[:density])
    else
      # Outside cloud - use entrainment-based calculation
      concentration = calculate_entrainment_concentration(x, y, z, time, cloud_props)
    end
    
    # Apply atmospheric dilution
    concentration *= calculate_atmospheric_dilution(distance_from_center, time)
    
    concentration
  end
  
  # Calculate Pasquill-Gifford dispersion coefficients
  def calculate_sigma_y(x)
    # ALOHA dispersion coefficients based on Pasquill stability class
    # Distance x in meters, returns σy in meters
    
    case pasquill_stability_class
    when 'A' # Very unstable
      0.22 * x * (1 + 0.0001 * x)**(-0.5)
    when 'B' # Moderately unstable  
      0.16 * x * (1 + 0.0001 * x)**(-0.5)
    when 'C' # Slightly unstable
      0.11 * x * (1 + 0.0001 * x)**(-0.5)
    when 'D' # Neutral
      0.08 * x * (1 + 0.0001 * x)**(-0.5)
    when 'E' # Slightly stable
      0.06 * x * (1 + 0.0001 * x)**(-0.5)
    when 'F' # Moderately stable
      0.04 * x * (1 + 0.0001 * x)**(-0.5)
    end
  end
  
  def calculate_sigma_z(x)
    # Vertical dispersion coefficients
    case pasquill_stability_class
    when 'A'
      0.20 * x
    when 'B'
      0.12 * x  
    when 'C'
      0.08 * x * (1 + 0.0002 * x)**(-0.5)
    when 'D'
      0.06 * x * (1 + 0.0015 * x)**(-0.5)
    when 'E'
      0.03 * x * (1 + 0.0003 * x)**(-1)
    when 'F'
      0.016 * x * (1 + 0.0003 * x)**(-1)
    end
  end
  
  # Wind speed at specific height (power law profile)
  def wind_speed_at_height(height)
    # u(z) = u_ref * (z / z_ref)^p
    # where p depends on stability class and surface roughness
    
    z_ref = 10.0 # Reference height (10m)
    u_ref = wind_speed_at_10m
    
    power_exponent = case pasquill_stability_class
                    when 'A', 'B' then 0.1  # Unstable
                    when 'C', 'D' then 0.15 # Neutral
                    when 'E', 'F' then 0.35 # Stable
                    end
    
    # Apply surface roughness correction
    if surface_roughness_length && surface_roughness_length > 0
      power_exponent *= (surface_roughness_length / 0.1)**0.2
    end
    
    u_ref * (height / z_ref)**power_exponent
  end
  
  # Plume rise calculation (Briggs equations)
  def calculate_plume_rise(distance)
    return 0.0 unless buoyancy_flux && buoyancy_flux > 0
    
    # Briggs plume rise formulas
    if pasquill_stability_class.in?(%w[A B C])
      # Unstable/neutral conditions
      delta_h = 1.6 * (buoyancy_flux**(1.0/3.0)) * (distance**(2.0/3.0)) / wind_speed_at_release
    else
      # Stable conditions
      s = calculate_stability_parameter
      delta_h = 2.6 * (buoyancy_flux / (wind_speed_at_release * s))**(1.0/3.0)
    end
    
    # Apply momentum plume rise if significant
    if momentum_flux && momentum_flux > 0
      momentum_rise = 1.5 * (momentum_flux / wind_speed_at_release)**(1.0/3.0) * 
                     distance**(2.0/3.0)
      delta_h = [delta_h, momentum_rise].max
    end
    
    delta_h
  end
  
  # Generate spatial calculation grid
  def generate_spatial_grid
    points = []
    
    x_max = max_downwind_distance
    y_max = max_crosswind_distance
    resolution = grid_resolution
    
    (0..x_max).step(resolution) do |x|
      (-y_max..y_max).step(resolution) do |y|
        # Ground level calculation (z = 0)
        points << {
          x: x,
          y: y, 
          z: 0.0,
          lat: calculate_latitude(x, y),
          lon: calculate_longitude(x, y)
        }
      end
    end
    
    points
  end
  
  # Create plume calculation record
  def create_plume_calculation(point, step, elapsed, concentration)
    sigma_y = calculate_sigma_y(point[:x])
    sigma_z = calculate_sigma_z(point[:x])
    
    plume_calculations.create!(
      downwind_distance: point[:x],
      crosswind_distance: point[:y],
      vertical_distance: point[:z],
      latitude: point[:lat],
      longitude: point[:lon],
      time_step: step,
      elapsed_time: elapsed,
      ground_level_concentration: concentration,
      centerline_concentration: concentration * Math.exp(0.5 * (point[:y] / sigma_y)**2),
      maximum_concentration: concentration,
      sigma_y: sigma_y,
      sigma_z: sigma_z,
      plume_height: effective_release_height + calculate_plume_rise(point[:x]),
      plume_width: 4.0 * sigma_y,  # ±2σ covers ~95% of plume
      plume_depth: 2.0 * sigma_z,
      local_wind_speed: wind_speed_at_height(effective_release_height),
      dilution_factor: calculate_dilution_factor(point[:x], point[:y]),
      air_density: calculate_air_density
    )
  end
  
  # Calculate receptor impacts against toxicological guidelines
  def calculate_receptor_impacts!
    return unless dispersion_scenario.chemical.toxicological_data
    
    receptors = Receptor.joins(:dispersion_event)
                       .where(dispersion_events: { id: dispersion_scenario.id })
    
    receptors.find_each do |receptor|
      calculate_receptor_impact(receptor)
    end
  end
  
  def calculate_receptor_impact(receptor)
    # Find plume calculations at receptor location
    receptor_calcs = plume_calculations
      .where(
        latitude: receptor.latitude.round(7),
        longitude: receptor.longitude.round(7)
      )
      .order(:elapsed_time)
    
    return if receptor_calcs.empty?
    
    # Calculate peak concentration and timing
    peak_calc = receptor_calcs.maximum(:ground_level_concentration)
    peak_time = receptor_calcs.find_by(ground_level_concentration: peak_calc)&.elapsed_time
    
    # Calculate time-weighted averages for different durations
    twa_1hr = calculate_time_weighted_average(receptor_calcs, 60.0)
    twa_8hr = calculate_time_weighted_average(receptor_calcs, 480.0)
    
    # Assess against toxicological guidelines
    tox_data = chemical.toxicological_data
    health_impact = assess_health_impact(peak_calc, twa_1hr, tox_data)
    
    receptor_calculations.create!(
      receptor: receptor,
      peak_concentration: peak_calc,
      time_weighted_average: twa_1hr,
      integrated_dose: receptor_calcs.sum(:ground_level_concentration) * calculation_time_step,
      arrival_time: receptor_calcs.first.elapsed_time,
      peak_time: peak_time,
      duration_above_threshold: calculate_duration_above_threshold(receptor_calcs, tox_data.aegl_1_1hr),
      threshold_concentration: tox_data.aegl_1_1hr,
      health_impact_level: health_impact[:level],
      aegl_fraction: health_impact[:aegl_fraction],
      erpg_fraction: health_impact[:erpg_fraction],
      pac_fraction: health_impact[:pac_fraction],
      health_impact_notes: health_impact[:notes],
      distance_from_source: receptor.distance_from_source,
      angle_from_source: calculate_angle_to_receptor(receptor)
    )
  end
  
  # Health impact assessment based on AEGL/ERPG guidelines
  def assess_health_impact(peak_concentration, twa_concentration, tox_data)
    return { level: 'no_effect', aegl_fraction: 0, erpg_fraction: 0, pac_fraction: 0, notes: 'No toxicological data' } unless tox_data
    
    # Check against AEGL levels (1-hour exposure)
    aegl_3 = tox_data.aegl_3_1hr || Float::INFINITY
    aegl_2 = tox_data.aegl_2_1hr || Float::INFINITY  
    aegl_1 = tox_data.aegl_1_1hr || Float::INFINITY
    
    # Check against ERPG levels
    erpg_3 = tox_data.erpg_3 || Float::INFINITY
    erpg_2 = tox_data.erpg_2 || Float::INFINITY
    erpg_1 = tox_data.erpg_1 || Float::INFINITY
    
    # Calculate fractions of guidelines
    aegl_fraction = aegl_1 > 0 ? [peak_concentration / aegl_1, twa_concentration / aegl_1].max : 0
    erpg_fraction = erpg_1 > 0 ? [peak_concentration / erpg_1, twa_concentration / erpg_1].max : 0
    pac_fraction = 0 # TODO: Implement PAC calculations
    
    # Determine impact level
    level = if peak_concentration >= aegl_3 || peak_concentration >= erpg_3
              'life_threatening'
            elsif peak_concentration >= aegl_2 || peak_concentration >= erpg_2
              'disabling'
            elsif peak_concentration >= aegl_1 || peak_concentration >= erpg_1
              'notable'
            elsif aegl_fraction > 0.1 || erpg_fraction > 0.1
              'mild'
            else
              'no_effect'
            end
    
    notes = "Peak: #{peak_concentration.round(3)} mg/m³, " \
           "TWA: #{twa_concentration.round(3)} mg/m³, " \
           "AEGL-1: #{aegl_1.round(3)} mg/m³, " \
           "ERPG-1: #{erpg_1.round(3)} mg/m³"
    
    {
      level: level,
      aegl_fraction: aegl_fraction,
      erpg_fraction: erpg_fraction,
      pac_fraction: pac_fraction,
      notes: notes
    }
  end
  
  private
  
  def validate_gaussian_parameters!
    raise ArgumentError, "Invalid wind speed" if wind_speed_at_release <= 0
    raise ArgumentError, "Invalid release height" if effective_release_height < 0
    raise ArgumentError, "Missing dispersion coefficients" unless sigma_y_coefficient || pasquill_stability_class
  end
  
  def validate_heavy_gas_parameters!
    validate_gaussian_parameters!
    raise ArgumentError, "Missing density ratio for heavy gas" unless density_ratio && density_ratio > 1.0
    raise ArgumentError, "Missing initial cloud radius" unless initial_cloud_radius && initial_cloud_radius > 0
  end
  
  def interpolate_release_rate(time)
    # Get release rate from source calculations at this time
    calc = release_calculations.where('time_elapsed <= ?', time).order(:time_elapsed).last
    calc&.instantaneous_release_rate || 0.0
  end
  
  def calculate_latitude(x, y)
    # Convert local coordinates to lat/lon
    dispersion_scenario.latitude + (y / 111320.0) # Approximate meters to degrees
  end
  
  def calculate_longitude(x, y)
    cos_lat = Math.cos(dispersion_scenario.latitude * Math::PI / 180.0)
    dispersion_scenario.longitude + (x / (111320.0 * cos_lat))
  end
  
  def calculate_dilution_factor(x, y)
    sigma_y = calculate_sigma_y(x)
    sigma_z = calculate_sigma_z(x)
    u = wind_speed_at_height(effective_release_height)
    
    2 * Math::PI * sigma_y * sigma_z * u
  end
  
  def calculate_air_density
    # Standard air density at sea level, adjust for temperature and pressure
    p = ambient_pressure || 101325.0 # Pa
    t = ambient_temperature || 288.15 # K
    r = 287.05 # J/(kg·K) - specific gas constant for dry air
    
    p / (r * t)
  end
  
  def ambient_pressure
    dispersion_scenario.ambient_pressure
  end
  
  def ambient_temperature
    dispersion_scenario.ambient_temperature&.+(273.15) # Convert C to K
  end
  
  def calculate_time_weighted_average(calculations, duration_minutes)
    relevant_calcs = calculations.where('elapsed_time <= ?', duration_minutes)
    return 0.0 if relevant_calcs.empty?
    
    total_exposure = relevant_calcs.sum { |calc| calc.ground_level_concentration * calculation_time_step }
    total_exposure / duration_minutes
  end
  
  def calculate_duration_above_threshold(calculations, threshold)
    return 0.0 unless threshold && threshold > 0
    
    above_threshold = calculations.where('ground_level_concentration >= ?', threshold)
    above_threshold.count * calculation_time_step
  end
  
  def calculate_angle_to_receptor(receptor)
    dx = receptor.longitude - dispersion_scenario.longitude
    dy = receptor.latitude - dispersion_scenario.latitude
    
    Math.atan2(dy, dx) * 180.0 / Math::PI
  end
end