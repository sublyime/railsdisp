# Thermal Radiation Incident model implementing ALOHA thermal radiation modeling
# Handles BLEVE-Fireball, Jet Fire, and Pool Fire calculations with view factors and thermal dose
class ThermalRadiationIncident < ApplicationRecord
  belongs_to :dispersion_scenario
  has_many :thermal_calculations, dependent: :destroy
  has_many :thermal_zones, dependent: :destroy
  has_many :equipment_thermal_damages, dependent: :destroy
  
  # Model validation
  validates :incident_type, inclusion: { in: %w[bleve_fireball jet_fire pool_fire flash_fire] }
  validates :fire_category, inclusion: { 
    in: %w[pressurized_release liquid_spill tank_failure pipeline_rupture vapor_release] 
  }, allow_nil: true
  validates :fuel_mass, :release_rate, :ambient_temperature, :ambient_pressure,
            presence: true, numericality: { greater_than: 0 }
  validates :calculation_status, inclusion: { in: %w[pending calculating completed failed] }
  validates :radiative_fraction, numericality: { in: 0..1 }, allow_nil: true
  validates :transmissivity, numericality: { in: 0..1 }, allow_nil: true
  
  # Delegate to scenario for convenience
  delegate :chemical, :latitude, :longitude, to: :dispersion_scenario
  
  # Scopes for filtering
  scope :by_incident_type, ->(type) { where(incident_type: type) }
  scope :completed, -> { where(calculation_status: 'completed') }
  scope :high_intensity, -> { where('maximum_heat_flux > ?', 37500) } # >37.5 kW/m²
  scope :recent, -> { order(created_at: :desc) }
  scope :long_duration, -> { where('fire_duration > ?', 300) } # >5 minutes
  
  # Physical constants
  STEFAN_BOLTZMANN = 5.67e-8 # W/m²/K⁴ - Stefan-Boltzmann constant
  SOLAR_CONSTANT = 1000.0 # W/m² - solar irradiance for reference
  STANDARD_GRAVITY = 9.81 # m/s²
  AIR_MOLECULAR_WEIGHT = 0.029 # kg/mol
  
  # Heat flux damage thresholds (W/m²)
  HEAT_FLUX_THRESHOLDS = {
    'no_effect' => 1000,           # 1.0 kW/m² - no effects
    'discomfort' => 2500,          # 2.5 kW/m² - discomfort after 1 minute
    'pain' => 5000,                # 5.0 kW/m² - pain in 15-20 seconds
    'injury' => 12500,             # 12.5 kW/m² - injury in 30 seconds
    'severe_burn' => 25000,        # 25.0 kW/m² - severe burns
    'lethality' => 37500,          # 37.5 kW/m² - potentially lethal
    'equipment_damage' => 50000,   # 50.0 kW/m² - equipment damage
    'structural_damage' => 100000  # 100.0 kW/m² - structural damage
  }.freeze
  
  # Thermal dose coefficients for burn injury (Eisenberg probit model)
  THERMAL_DOSE_COEFFICIENTS = {
    'pain' => { a: -39.83, b: 3.0186 },
    'first_degree' => { a: -43.14, b: 3.0186 },
    'second_degree' => { a: -36.38, b: 2.56 },
    'lethality' => { a: -36.38, b: 2.56 }
  }.freeze
  
  # Fire type specific parameters
  FIRE_TYPE_PARAMETERS = {
    'bleve_fireball' => {
      radiative_fraction: 0.3,
      flame_temperature: 1200,
      surface_emissive_power: 200000,
      typical_duration_factor: 0.45 # D = 0.45 * M^0.32
    },
    'jet_fire' => {
      radiative_fraction: 0.2,
      flame_temperature: 1400,
      surface_emissive_power: 150000,
      typical_length_factor: 5.3 # L = 5.3 * Q^0.4
    },
    'pool_fire' => {
      radiative_fraction: 0.25,
      flame_temperature: 1100,
      surface_emissive_power: 60000,
      burn_rate_factor: 0.001 # typical burn rate kg/m²/s
    },
    'flash_fire' => {
      radiative_fraction: 0.15,
      flame_temperature: 1000,
      surface_emissive_power: 80000,
      propagation_speed: 5.0 # m/s typical flame speed
    }
  }.freeze
  
  # Main calculation method
  def calculate_thermal_radiation!
    update!(calculation_status: 'calculating', last_calculated_at: Time.current)
    
    begin
      validate_thermal_parameters!
      
      # Clear existing calculations
      thermal_calculations.destroy_all
      thermal_zones.destroy_all
      equipment_thermal_damages.destroy_all
      
      # Calculate fire characteristics based on type
      calculate_fire_characteristics!
      
      # Generate spatial grid for thermal calculations
      grid_points = generate_calculation_grid
      
      # Calculate thermal radiation at each point
      grid_points.each do |point|
        heat_flux = calculate_heat_flux(point[:distance], point[:angle])
        
        next if heat_flux < 100 # Skip negligible heat flux (<100 W/m²)
        
        create_thermal_calculation(point, heat_flux)
      end
      
      # Generate thermal zones
      generate_thermal_zones!
      
      # Calculate equipment damage
      calculate_equipment_damage!
      
      update!(calculation_status: 'completed')
      
    rescue StandardError => e
      update!(
        calculation_status: 'failed',
        calculation_warnings: "Calculation failed: #{e.message}"
      )
      raise
    end
  end
  
  # Calculate fire characteristics based on incident type
  def calculate_fire_characteristics!
    case incident_type
    when 'bleve_fireball'
      calculate_bleve_fireball_characteristics!
    when 'jet_fire'
      calculate_jet_fire_characteristics!
    when 'pool_fire'
      calculate_pool_fire_characteristics!
    when 'flash_fire'
      calculate_flash_fire_characteristics!
    end
    
    # Calculate atmospheric effects
    calculate_atmospheric_effects!
    
    save!
  end
  
  # BLEVE-Fireball calculations
  def calculate_bleve_fireball_characteristics!
    # Fireball diameter correlation (Moorhouse and Pritchard)
    # D = 5.8 * M^0.32 for hydrocarbons
    self.fire_diameter = 5.8 * (fuel_mass ** 0.32)
    
    # Fireball duration correlation
    # t = 0.45 * M^0.32 for M in kg
    self.fire_duration = 0.45 * (fuel_mass ** 0.32)
    
    # Fireball height (center of mass)
    # H = D for spherical fireball, adjusted for buoyancy
    self.fire_height = fire_diameter
    
    # Surface emissive power (Mudan correlation)
    # SEP = 280 * (M/1000)^0.32 for M > 1000 kg
    if fuel_mass > 1000
      self.surface_emissive_power = 280000 * ((fuel_mass / 1000.0) ** 0.32)
    else
      self.surface_emissive_power = 200000 # Default for smaller fireballs
    end
    
    # Radiative fraction
    self.radiative_fraction = FIRE_TYPE_PARAMETERS['bleve_fireball'][:radiative_fraction]
    
    # Flame temperature
    self.flame_temperature = FIRE_TYPE_PARAMETERS['bleve_fireball'][:flame_temperature]
    
    # Calculate maximum heat flux at optimal distance
    self.maximum_heat_flux = calculate_maximum_heat_flux_bleve
  end
  
  # Jet Fire calculations
  def calculate_jet_fire_characteristics!
    # Jet fire length correlation (Hawthorne et al.)
    # L = 5.3 * Q^0.4 where Q is heat release rate (MW)
    heat_release_rate = calculate_heat_release_rate # MW
    self.fire_height = 5.3 * (heat_release_rate ** 0.4)
    
    # Jet fire diameter (empirical)
    # Based on momentum-controlled regime
    velocity = calculate_jet_velocity
    self.fire_diameter = Math.sqrt(4 * release_rate / (Math::PI * calculate_air_density * velocity))
    
    # Jet fire duration (continuous release or inventory dependent)
    if fuel_volume.present? && release_rate > 0
      self.fire_duration = (fuel_mass / release_rate).round(1)
    else
      self.fire_duration = 3600 # 1 hour default for continuous
    end
    
    # Surface emissive power for jet fires
    self.surface_emissive_power = FIRE_TYPE_PARAMETERS['jet_fire'][:surface_emissive_power]
    
    # Radiative fraction
    self.radiative_fraction = FIRE_TYPE_PARAMETERS['jet_fire'][:radiative_fraction]
    
    # Flame temperature
    self.flame_temperature = FIRE_TYPE_PARAMETERS['jet_fire'][:flame_temperature]
    
    # Calculate maximum heat flux
    self.maximum_heat_flux = calculate_maximum_heat_flux_jet
  end
  
  # Pool Fire calculations
  def calculate_pool_fire_characteristics!
    # Pool fire diameter (user input or calculated from spill area)
    if fire_diameter.blank?
      # Calculate from fuel volume and spill depth
      spill_depth = 0.01 # 1 cm typical depth for spill
      spill_area = fuel_volume / spill_depth
      self.fire_diameter = 2 * Math.sqrt(spill_area / Math::PI)
    end
    
    # Pool fire height correlation (Thomas)
    # H/D = 42 * (m_dot/ρ∞ * sqrt(gD))^0.61
    burn_rate = calculate_pool_burn_rate # kg/m²/s
    air_density = calculate_air_density
    
    dimensionless_burn_rate = burn_rate / (air_density * Math.sqrt(STANDARD_GRAVITY * fire_diameter))
    height_ratio = 42 * (dimensionless_burn_rate ** 0.61)
    self.fire_height = height_ratio * fire_diameter
    
    # Pool fire duration
    if fuel_volume.present?
      pool_area = Math::PI * (fire_diameter / 2.0) ** 2
      total_burn_rate = burn_rate * pool_area # kg/s
      fuel_density = chemical.density || 800.0 # kg/m³
      fuel_mass_pool = fuel_volume * fuel_density
      self.fire_duration = fuel_mass_pool / total_burn_rate
    else
      self.fire_duration = 1800 # 30 minutes default
    end
    
    # Surface emissive power (Mudan)
    # SEP = 20-40 kW/m² for small pools, up to 150 kW/m² for large pools
    if fire_diameter < 10
      self.surface_emissive_power = 40000
    elsif fire_diameter < 50
      self.surface_emissive_power = 80000
    else
      self.surface_emissive_power = 150000
    end
    
    # Store burn rate for use in calculations
    self.burn_rate = burn_rate
    
    # Radiative fraction
    self.radiative_fraction = FIRE_TYPE_PARAMETERS['pool_fire'][:radiative_fraction]
    
    # Flame temperature
    self.flame_temperature = FIRE_TYPE_PARAMETERS['pool_fire'][:flame_temperature]
    
    # Calculate maximum heat flux
    self.maximum_heat_flux = calculate_maximum_heat_flux_pool
  end
  
  # Flash Fire calculations (simplified)
  def calculate_flash_fire_characteristics!
    # Flash fire characteristics
    self.fire_height = 3.0 # m - typical flash fire height
    self.fire_duration = 5.0 # s - very short duration
    
    # Calculate fire diameter from vapor cloud
    if fuel_mass.present?
      # Estimate vapor cloud diameter
      vapor_density = calculate_vapor_density
      cloud_volume = fuel_mass / vapor_density
      self.fire_diameter = 2 * ((3 * cloud_volume) / (4 * Math::PI)) ** (1.0/3.0)
    else
      self.fire_diameter = 50.0 # Default 50m diameter
    end
    
    # Flash fire emissive power
    self.surface_emissive_power = FIRE_TYPE_PARAMETERS['flash_fire'][:surface_emissive_power]
    
    # Radiative fraction
    self.radiative_fraction = FIRE_TYPE_PARAMETERS['flash_fire'][:radiative_fraction]
    
    # Flame temperature
    self.flame_temperature = FIRE_TYPE_PARAMETERS['flash_fire'][:flame_temperature]
    
    # Maximum heat flux
    self.maximum_heat_flux = surface_emissive_power * 0.5 # Conservative estimate
  end
  
  # Calculate heat flux at specific distance and angle
  def calculate_heat_flux(distance, angle = 0)
    return 0.0 if distance <= 0 || fire_diameter <= 0
    
    # Calculate view factor based on fire geometry
    view_factor = calculate_view_factor(distance, angle)
    
    # Calculate atmospheric transmittance
    transmittance = calculate_atmospheric_transmittance(distance)
    
    # Calculate incident heat flux
    # q" = F * SEP * τ
    incident_flux = view_factor * surface_emissive_power * transmittance
    
    # Apply wind effects for tilted flames
    wind_factor = calculate_wind_factor(distance, angle)
    
    incident_flux * wind_factor
  end
  
  # Calculate view factor using appropriate method
  def calculate_view_factor(distance, angle)
    case incident_type
    when 'bleve_fireball'
      calculate_view_factor_sphere(distance)
    when 'jet_fire'
      calculate_view_factor_cylinder(distance, angle)
    when 'pool_fire'
      calculate_view_factor_cylinder(distance, angle)
    when 'flash_fire'
      calculate_view_factor_sphere(distance) # Simplified as sphere
    else
      0.0
    end
  end
  
  # View factor for spherical fireball (point receptor)
  def calculate_view_factor_sphere(distance)
    return 0.0 if distance <= fire_diameter / 2.0 # Inside fireball
    
    radius = fire_diameter / 2.0
    
    # View factor for sphere to point
    # F = (R/L)² / (1 + (R/L)²)²
    r_over_l = radius / distance
    
    view_factor = (r_over_l ** 2) / ((1 + r_over_l ** 2) ** 2)
    
    # Geometric correction for elevated fireball
    if fire_height > 0
      elevation_angle = Math.atan(fire_height / distance)
      cos_correction = Math.cos(elevation_angle)
      view_factor *= cos_correction
    end
    
    [view_factor, 1.0].min # Cap at unity
  end
  
  # View factor for cylindrical flame (jet fire, pool fire)
  def calculate_view_factor_cylinder(distance, angle)
    return 0.0 if distance <= fire_diameter / 2.0
    
    radius = fire_diameter / 2.0
    height = fire_height
    
    # Simplified cylindrical flame view factor
    # Using solid flame model approximation
    
    # Calculate view factor to vertical cylinder
    l_over_r = height / radius
    r_over_x = radius / distance
    
    # Empirical correlation for cylinder view factor
    if l_over_r < 1.0
      # Short cylinder (like pool fire)
      view_factor = calculate_view_factor_disk(distance) * (height / radius)
    else
      # Tall cylinder (like jet fire)
      view_factor = calculate_view_factor_vertical_cylinder(distance, height, radius)
    end
    
    # Apply angle correction for horizontal displacement
    if angle.abs > 0
      angle_correction = Math.cos(angle * Math::PI / 180.0)
      view_factor *= [angle_correction, 0.1].max # Minimum 10% for scattered radiation
    end
    
    [view_factor, 1.0].min
  end
  
  # View factor for disk (pool fire base)
  def calculate_view_factor_disk(distance)
    radius = fire_diameter / 2.0
    h_over_r = distance / radius
    
    # View factor for disk normal to line of sight
    # F = 1 / (1 + H²/R²)
    1.0 / (1.0 + h_over_r ** 2)
  end
  
  # View factor for vertical cylinder
  def calculate_view_factor_vertical_cylinder(distance, height, radius)
    # Simplified view factor for vertical cylinder
    # More complex formulation would require integration
    
    h_over_x = height / distance
    r_over_x = radius / distance
    
    # Approximate view factor
    view_factor = (2 / Math::PI) * (h_over_x * Math.atan(r_over_x) + 
                                   r_over_x * Math.atan(h_over_x))
    
    [view_factor, 1.0].min
  end
  
  # Calculate atmospheric transmittance
  def calculate_atmospheric_transmittance(distance)
    # Beer's law: τ = exp(-k * L)
    # where k is absorption coefficient, L is path length
    
    absorption_coeff = atmospheric_absorption_coefficient || calculate_absorption_coefficient
    path_length = distance
    
    transmittance = Math.exp(-absorption_coeff * path_length)
    
    # Additional humidity effects
    if relative_humidity.present? && relative_humidity > 0.3
      humidity_factor = 1.0 - (relative_humidity - 0.3) * 0.1
      transmittance *= [humidity_factor, 0.7].max # Minimum 70% transmission
    end
    
    [transmittance, 1.0].min
  end
  
  # Calculate thermal dose and injury probabilities
  def calculate_thermal_dose(heat_flux, exposure_time = nil)
    exposure_time ||= fire_duration
    
    # Thermal dose calculation
    # Φ = q"^(4/3) * t (for second-degree burns)
    thermal_dose = (heat_flux ** (4.0/3.0)) * exposure_time
    
    # Calculate injury probabilities using probit models
    injury_probs = {}
    
    THERMAL_DOSE_COEFFICIENTS.each do |injury_type, coeffs|
      if thermal_dose > 0
        probit = coeffs[:a] + coeffs[:b] * Math.log(thermal_dose)
        probability = probit_to_probability(probit)
        injury_probs[injury_type] = probability
      else
        injury_probs[injury_type] = 0.0
      end
    end
    
    {
      thermal_dose: thermal_dose,
      probabilities: injury_probs
    }
  end
  
  # Generate calculation grid
  def generate_calculation_grid
    points = []
    max_dist = max_calculation_distance
    resolution = calculation_resolution
    sectors = calculation_sectors
    
    # Radial grid with finer resolution near source
    distances = []
    
    # Fine grid near source
    (resolution/4..resolution*2).step(resolution/4) { |d| distances << d }
    
    # Medium grid in middle
    (resolution*2..max_dist/2).step(resolution) { |d| distances << d }
    
    # Coarse grid far field
    (max_dist/2..max_dist).step(resolution*2) { |d| distances << d }
    
    distances.each do |distance|
      (0...sectors).each do |sector|
        angle = sector * 360.0 / sectors
        
        # Convert to Cartesian coordinates
        x = distance * Math.cos(angle * Math::PI / 180.0)
        y = distance * Math.sin(angle * Math::PI / 180.0)
        
        points << {
          distance: distance,
          angle: angle,
          x: x,
          y: y,
          lat: latitude + (y / 111320.0),
          lon: longitude + (x / (111320.0 * Math.cos(latitude * Math::PI / 180.0)))
        }
      end
    end
    
    points
  end
  
  # Create thermal calculation record
  def create_thermal_calculation(point, heat_flux)
    view_factor = calculate_view_factor(point[:distance], point[:angle])
    transmittance = calculate_atmospheric_transmittance(point[:distance])
    
    # Calculate thermal dose and injury assessment
    dose_calc = calculate_thermal_dose(heat_flux)
    thermal_dose = dose_calc[:thermal_dose]
    injury_probs = dose_calc[:probabilities]
    
    # Assess thermal damage level
    damage_level = assess_thermal_damage_level(heat_flux)
    
    # Calculate time to various thermal effects
    times = calculate_thermal_effect_times(heat_flux)
    
    thermal_calculations.create!(
      distance_from_source: point[:distance],
      angle_from_source: point[:angle],
      latitude: point[:lat],
      longitude: point[:lon],
      view_factor: view_factor,
      incident_heat_flux: heat_flux,
      absorbed_heat_flux: heat_flux * (1 - (chemical.reflectivity || 0.1)),
      net_heat_flux: heat_flux,
      atmospheric_transmittance: transmittance,
      path_length: point[:distance],
      thermal_dose: thermal_dose,
      time_to_pain: times[:pain],
      time_to_2nd_degree_burn: times[:second_degree],
      time_to_death: times[:lethality],
      thermal_damage_level: damage_level,
      burn_probability: injury_probs['second_degree'],
      lethality_probability: injury_probs['lethality']
    )
  end
  
  # Generate thermal zones based on heat flux thresholds
  def generate_thermal_zones!
    HEAT_FLUX_THRESHOLDS.each do |zone_type, threshold_flux|
      # Find maximum radius for this threshold
      max_radius = find_heat_flux_radius(threshold_flux)
      next if max_radius <= 0
      
      # Create zone geometry
      zone_area = Math::PI * max_radius**2
      
      # Estimate population in zone
      pop_density = 1000 # people per km²
      estimated_population = (zone_area / 1e6) * pop_density
      
      thermal_zones.create!(
        heat_flux_threshold: threshold_flux,
        zone_type: zone_type,
        zone_description: describe_thermal_effects(zone_type),
        max_radius: max_radius,
        zone_area: zone_area,
        zone_area_km2: zone_area / 1e6,
        estimated_population_affected: estimated_population.round,
        evacuation_required: threshold_flux >= HEAT_FLUX_THRESHOLDS['pain'],
        evacuation_radius: max_radius * 1.5, # 50% safety margin
        emergency_response_required: threshold_flux >= HEAT_FLUX_THRESHOLDS['injury'],
        fire_suppression_required: threshold_flux >= HEAT_FLUX_THRESHOLDS['equipment_damage'],
        medical_response_required: threshold_flux >= HEAT_FLUX_THRESHOLDS['injury'],
        protective_actions: generate_protective_actions(zone_type).to_json
      )
    end
  end
  
  private
  
  def validate_thermal_parameters!
    raise ArgumentError, "Invalid fuel mass" if fuel_mass <= 0
    raise ArgumentError, "Invalid release rate" if release_rate <= 0
    raise ArgumentError, "Invalid ambient temperature" if ambient_temperature <= 0
    raise ArgumentError, "Invalid ambient pressure" if ambient_pressure <= 0
  end
  
  def calculate_atmospheric_effects!
    # Calculate atmospheric absorption coefficient if not provided
    unless atmospheric_absorption_coefficient.present?
      # Wayne's correlation for water vapor absorption
      # k = 7.9 * (RH/100) * (1/T)^2 for T in K
      rh_fraction = (relative_humidity || 0.5) # Default 50% RH
      temp_factor = (ambient_temperature || 288.15)
      
      self.atmospheric_absorption_coefficient = 7.9e-3 * rh_fraction * (288.15 / temp_factor)**2
    end
    
    # Calculate transmissivity for visibility/meteorological range
    unless transmissivity.present?
      # Typical clear day transmissivity
      self.transmissivity = 0.9
    end
  end
  
  def calculate_heat_release_rate
    # Calculate heat release rate in MW
    if chemical.heat_of_combustion.present?
      (release_rate * chemical.heat_of_combustion) / 1e6 # MW
    else
      (release_rate * 45e6) / 1e6 # MW, assuming 45 MJ/kg for hydrocarbons
    end
  end
  
  def calculate_jet_velocity
    # Calculate jet velocity from pressure and temperature
    if release_pressure.present? && release_temperature.present?
      # Simplified choked flow velocity
      gamma = 1.3 # Heat capacity ratio for hydrocarbons
      r_specific = 287.0 # Specific gas constant
      
      Math.sqrt(gamma * r_specific * release_temperature)
    else
      100.0 # m/s default velocity
    end
  end
  
  def calculate_air_density
    # Calculate air density at ambient conditions
    r_air = 287.0 # J/kg/K
    ambient_pressure / (r_air * ambient_temperature)
  end
  
  def calculate_pool_burn_rate
    # Calculate pool fire burn rate (Babrauskas correlation)
    # m_dot = 0.001 * (1 - exp(-k*D)) kg/m²/s
    
    if chemical.name.downcase.include?('methane')
      k_value = 1.1
      max_burn_rate = 0.078
    elsif chemical.name.downcase.include?('propane')
      k_value = 2.1
      max_burn_rate = 0.099
    elsif chemical.name.downcase.include?('gasoline')
      k_value = 2.1
      max_burn_rate = 0.055
    else
      # Default hydrocarbon
      k_value = 2.0
      max_burn_rate = 0.060
    end
    
    max_burn_rate * (1 - Math.exp(-k_value * fire_diameter))
  end
  
  def calculate_vapor_density
    # Calculate vapor density for flash fire
    if chemical.molecular_weight.present?
      # Ideal gas law: ρ = PM/RT
      mw = chemical.molecular_weight / 1000.0 # kg/mol
      r_universal = 8314.0 # J/kmol/K
      
      (ambient_pressure * mw) / (r_universal * ambient_temperature)
    else
      2.0 # kg/m³ default for light hydrocarbons
    end
  end
  
  def calculate_maximum_heat_flux_bleve
    # Maximum heat flux for BLEVE at optimal distance
    optimal_distance = fire_diameter * 1.5 # Typically 1.5 diameters
    calculate_heat_flux(optimal_distance)
  end
  
  def calculate_maximum_heat_flux_jet
    # Maximum heat flux for jet fire
    optimal_distance = fire_diameter * 2.0 # Side distance
    calculate_heat_flux(optimal_distance)
  end
  
  def calculate_maximum_heat_flux_pool
    # Maximum heat flux for pool fire
    optimal_distance = fire_diameter * 1.0 # Edge distance
    calculate_heat_flux(optimal_distance)
  end
  
  def calculate_absorption_coefficient
    # Default atmospheric absorption coefficient
    # Based on clear atmospheric conditions
    0.005 # m⁻¹ typical value
  end
  
  def calculate_wind_factor(distance, angle)
    return 1.0 unless wind_speed.present? && wind_speed > 2.0
    
    # Wind effects on flame tilt
    case incident_type
    when 'jet_fire', 'pool_fire'
      # Flame tilt affects view factor
      wind_angle = wind_direction || 0
      relative_angle = (angle - wind_angle).abs
      
      if relative_angle < 45
        1.2 # Downwind enhancement
      elsif relative_angle > 135
        0.8 # Upwind reduction
      else
        1.0 # Crosswind
      end
    else
      1.0 # No significant wind effects for fireballs
    end
  end
  
  def assess_thermal_damage_level(heat_flux)
    case heat_flux
    when 0...HEAT_FLUX_THRESHOLDS['discomfort']
      'none'
    when HEAT_FLUX_THRESHOLDS['discomfort']...HEAT_FLUX_THRESHOLDS['pain']
      'discomfort'
    when HEAT_FLUX_THRESHOLDS['pain']...HEAT_FLUX_THRESHOLDS['injury']
      'pain'
    when HEAT_FLUX_THRESHOLDS['injury']...HEAT_FLUX_THRESHOLDS['severe_burn']
      'injury'
    when HEAT_FLUX_THRESHOLDS['severe_burn']...HEAT_FLUX_THRESHOLDS['lethality']
      'severe_burn'
    else
      'lethality'
    end
  end
  
  def calculate_thermal_effect_times(heat_flux)
    # Calculate time to various thermal effects
    # Based on empirical correlations
    
    times = {}
    
    # Time to pain (seconds)
    if heat_flux >= 2500
      times[:pain] = 43.0 / (heat_flux / 1000.0) ** 1.33
    else
      times[:pain] = Float::INFINITY
    end
    
    # Time to second-degree burn
    if heat_flux >= 5000
      times[:second_degree] = 43.0 / (heat_flux / 1000.0) ** 1.33
    else
      times[:second_degree] = Float::INFINITY
    end
    
    # Time to lethality
    if heat_flux >= 25000
      times[:lethality] = 100.0 / (heat_flux / 1000.0) ** 2.0
    else
      times[:lethality] = Float::INFINITY
    end
    
    times
  end
  
  def probit_to_probability(probit)
    # Convert probit value to probability
    probability = 0.5 * (1 + Math.erf(probit / Math.sqrt(2)))
    [[probability, 0.0].max, 1.0].min
  end
  
  def find_heat_flux_radius(threshold_flux)
    # Binary search for radius where heat flux equals threshold
    low, high = 1.0, max_calculation_distance
    tolerance = 1.0 # 1 meter tolerance
    
    while (high - low) > tolerance
      mid = (low + high) / 2.0
      flux = calculate_heat_flux(mid)
      
      if flux > threshold_flux
        low = mid
      else
        high = mid
      end
    end
    
    flux_at_radius = calculate_heat_flux(low)
    flux_at_radius >= threshold_flux ? low : 0.0
  end
  
  def describe_thermal_effects(zone_type)
    case zone_type
    when 'no_effect'
      'No significant thermal effects'
    when 'discomfort'
      'Discomfort after prolonged exposure'
    when 'pain'
      'Pain in 15-20 seconds, blistering possible'
    when 'injury'
      'Second-degree burns in 30 seconds'
    when 'severe_burn'
      'Severe burns, significant injury likely'
    when 'lethality'
      'Potentially lethal exposure'
    when 'equipment_damage'
      'Equipment damage and ignition of combustibles'
    when 'structural_damage'
      'Structural damage to buildings'
    else
      'Thermal effects unknown'
    end
  end
  
  def generate_protective_actions(zone_type)
    case zone_type
    when 'no_effect', 'discomfort'
      ['Monitor situation', 'No immediate action required']
    when 'pain'
      ['Evacuate if feasible', 'Seek shelter', 'Cover exposed skin']
    when 'injury', 'severe_burn'
      ['Immediate evacuation required', 'Emergency medical response', 'Fire suppression']
    when 'lethality'
      ['Immediate evacuation', 'Emergency response', 'Medical triage']
    when 'equipment_damage', 'structural_damage'
      ['Industrial evacuation', 'Fire protection systems', 'Structural protection']
    else
      ['Monitor situation', 'Follow emergency instructions']
    end
  end
  
  def calculate_equipment_damage!
    # Calculate damage to buildings and equipment in the area
    # This would integrate with the buildings table
    
    buildings_in_area = Building.joins(:map_layer)
                              .where('ST_DWithin(ST_Point(longitude, latitude), ST_Point(?, ?), ?)',
                                    longitude, latitude, max_calculation_distance)
    
    buildings_in_area.find_each do |building|
      distance = calculate_distance_to_building(building)
      heat_flux = calculate_heat_flux(distance)
      
      next if heat_flux < 1000 # Skip negligible effects
      
      create_equipment_thermal_damage(building, heat_flux, distance)
    end
  rescue StandardError => e
    # Buildings table might not exist or have spatial functions
    Rails.logger.warn("Could not calculate equipment thermal damage: #{e.message}")
  end
  
  def calculate_distance_to_building(building)
    # Haversine distance calculation
    lat1, lon1 = latitude * Math::PI / 180, longitude * Math::PI / 180
    lat2, lon2 = building.latitude * Math::PI / 180, building.longitude * Math::PI / 180
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = Math.sin(dlat/2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    6371000 * c # Distance in meters
  end
  
  def create_equipment_thermal_damage(building, heat_flux, distance)
    # Determine equipment type and material
    equipment_type = infer_equipment_type(building)
    material_type = infer_material_type(building)
    
    # Calculate thermal exposure effects
    exposure_duration = fire_duration
    critical_temp = get_critical_temperature(material_type)
    
    # Assess damage
    damage_state = assess_equipment_damage_state(heat_flux, material_type)
    failure_prob = calculate_equipment_failure_probability(heat_flux, material_type)
    
    equipment_thermal_damages.create!(
      building: building,
      equipment_type: equipment_type,
      material_type: material_type,
      construction_standard: 'standard', # Default
      equipment_height: building.height,
      surface_area: building.area || (building.height * 20), # Estimated
      critical_temperature: critical_temp,
      incident_heat_flux: heat_flux,
      exposure_duration: exposure_duration,
      surface_temperature: calculate_surface_temperature(heat_flux, exposure_duration),
      time_to_failure: calculate_time_to_failure(heat_flux, material_type),
      damage_state: damage_state,
      failure_probability: failure_prob,
      structural_failure: damage_state.in?(['severe', 'failure']),
      escalation_potential: assess_escalation_potential(building, heat_flux),
      replacement_cost: estimate_replacement_cost(building),
      fire_protection_required: heat_flux >= HEAT_FLUX_THRESHOLDS['equipment_damage'],
      cooling_required: heat_flux >= HEAT_FLUX_THRESHOLDS['injury'],
      emergency_isolation_required: damage_state.in?(['severe', 'failure'])
    )
  end
  
  def infer_equipment_type(building)
    case building.building_type&.downcase
    when 'industrial'
      'storage_tank'
    when 'residential'
      'structure'
    when 'commercial'
      'structure'
    else
      'structure'
    end
  end
  
  def infer_material_type(building)
    # Simple inference based on building type
    case building.building_type&.downcase
    when 'industrial'
      'steel'
    when 'residential'
      'wood'
    when 'commercial'
      'concrete'
    else
      'steel'
    end
  end
  
  def get_critical_temperature(material_type)
    case material_type
    when 'steel'
      773.15 # 500°C - steel loses strength
    when 'aluminum'
      573.15 # 300°C - aluminum softening
    when 'concrete'
      673.15 # 400°C - concrete spalling
    when 'wood'
      533.15 # 260°C - wood ignition
    else
      673.15 # Default
    end
  end
  
  def assess_equipment_damage_state(heat_flux, material_type)
    thresholds = case material_type
                when 'steel'
                  { minor: 10000, moderate: 25000, severe: 50000, failure: 100000 }
                when 'aluminum'
                  { minor: 5000, moderate: 15000, severe: 30000, failure: 60000 }
                when 'concrete'
                  { minor: 15000, moderate: 35000, severe: 70000, failure: 120000 }
                when 'wood'
                  { minor: 2500, moderate: 10000, severe: 20000, failure: 40000 }
                else
                  { minor: 10000, moderate: 25000, severe: 50000, failure: 100000 }
                end
    
    case heat_flux
    when 0...thresholds[:minor]
      'none'
    when thresholds[:minor]...thresholds[:moderate]
      'minor'
    when thresholds[:moderate]...thresholds[:severe]
      'moderate'
    when thresholds[:severe]...thresholds[:failure]
      'severe'
    else
      'failure'
    end
  end
  
  def calculate_equipment_failure_probability(heat_flux, material_type)
    # Simplified failure probability based on heat flux
    damage_state = assess_equipment_damage_state(heat_flux, material_type)
    
    case damage_state
    when 'none' then 0.0
    when 'minor' then 0.1
    when 'moderate' then 0.3
    when 'severe' then 0.7
    when 'failure' then 0.95
    else 0.0
    end
  end
  
  def calculate_surface_temperature(heat_flux, duration)
    # Simplified surface temperature calculation
    # Assumes steel surface with typical properties
    base_temp = ambient_temperature || 288.15
    
    # Rough approximation: ΔT ≈ q" * t / (ρ * c * δ)
    # where δ is effective thermal penetration depth
    temp_rise = (heat_flux * duration) / (7800 * 500 * 0.01) # Steel properties
    
    base_temp + temp_rise
  end
  
  def calculate_time_to_failure(heat_flux, material_type)
    critical_temp = get_critical_temperature(material_type)
    base_temp = ambient_temperature || 288.15
    required_temp_rise = critical_temp - base_temp
    
    # Simplified: time = (ρ * c * δ * ΔT) / q"
    case material_type
    when 'steel'
      (7800 * 500 * 0.01 * required_temp_rise) / heat_flux
    when 'aluminum'
      (2700 * 900 * 0.01 * required_temp_rise) / heat_flux
    when 'concrete'
      (2300 * 1000 * 0.05 * required_temp_rise) / heat_flux
    when 'wood'
      (600 * 1500 * 0.02 * required_temp_rise) / heat_flux
    else
      (7800 * 500 * 0.01 * required_temp_rise) / heat_flux
    end
  end
  
  def assess_escalation_potential(building, heat_flux)
    # Assess if thermal exposure could cause escalation
    building.building_type&.downcase == 'industrial' && 
    heat_flux >= HEAT_FLUX_THRESHOLDS['equipment_damage']
  end
  
  def estimate_replacement_cost(building)
    # Simple replacement cost estimate
    cost_per_sqft = case building.building_type&.downcase
                   when 'residential' then 150
                   when 'commercial' then 200
                   when 'industrial' then 100
                   else 150
                   end
    
    area = building.area || 1000
    area * cost_per_sqft
  end
end