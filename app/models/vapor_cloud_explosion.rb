# Vapor Cloud Explosion model implementing Baker-Strehlow-Tang methodology
# Handles flame speed calculations, blast pressure predictions, and damage assessment
class VaporCloudExplosion < ApplicationRecord
  belongs_to :dispersion_scenario
  has_many :blast_calculations, dependent: :destroy
  has_many :explosion_zones, dependent: :destroy
  has_many :structural_damages, dependent: :destroy
  
  # Model validation
  validates :explosion_type, inclusion: { in: %w[vapor_cloud bleve confined unconfined] }
  validates :cloud_mass, :lower_flammability_limit, :upper_flammability_limit,
            :ambient_temperature, :ambient_pressure, presence: true, numericality: { greater_than: 0 }
  validates :calculation_status, inclusion: { in: %w[pending calculating completed failed] }
  validates :reactivity_index, inclusion: { in: 1..6 }, allow_nil: true
  validates :congestion_factor, :confinement_factor, :efficiency_factor, :yield_factor,
            numericality: { in: 0..1 }, allow_nil: true
  
  # Delegate to scenario and chemical for convenience
  delegate :chemical, to: :dispersion_scenario
  delegate :latitude, :longitude, to: :dispersion_scenario
  
  # Scopes for filtering
  scope :by_explosion_type, ->(type) { where(explosion_type: type) }
  scope :completed, -> { where(calculation_status: 'completed') }
  scope :high_risk, -> { where('maximum_overpressure > ?', 20000) } # >20 kPa
  scope :recent, -> { order(created_at: :desc) }
  
  # Physical constants
  GAMMA_AIR = 1.4 # Heat capacity ratio for air
  R_SPECIFIC_AIR = 287.0 # Specific gas constant for air (J/kg·K)
  SOUND_SPEED_STP = 343.0 # Speed of sound in air at STP (m/s)
  TNT_HEAT_COMBUSTION = 4.6e6 # TNT heat of combustion (J/kg)
  
  # Baker-Strehlow-Tang reactivity classes
  BST_REACTIVITY = {
    1 => { description: 'Low reactivity (propane, natural gas)', flame_speed_factor: 1.0 },
    2 => { description: 'Moderate reactivity (gasoline vapors)', flame_speed_factor: 2.0 },
    3 => { description: 'High reactivity (ethylene)', flame_speed_factor: 4.0 },
    4 => { description: 'Very high reactivity (acetylene)', flame_speed_factor: 8.0 },
    5 => { description: 'Extremely high reactivity (hydrogen)', flame_speed_factor: 16.0 },
    6 => { description: 'Detonable (acetylene-oxygen)', flame_speed_factor: 32.0 }
  }.freeze
  
  # Damage thresholds (Pa)
  DAMAGE_THRESHOLDS = {
    'window_breakage' => 3500,        # 0.5 psi
    'structural_damage' => 20700,     # 3 psi
    'building_collapse' => 48300,     # 7 psi
    'fatality_threshold' => 103400,   # 15 psi
    'total_destruction' => 172400     # 25 psi
  }.freeze
  
  # Main calculation method
  def calculate_explosion!
    update!(calculation_status: 'calculating', last_calculated_at: Time.current)
    
    begin
      validate_explosion_parameters!
      
      # Clear existing calculations
      blast_calculations.destroy_all
      explosion_zones.destroy_all
      structural_damages.destroy_all
      
      # Calculate fundamental explosion parameters
      calculate_explosion_characteristics!
      
      # Generate spatial grid for blast calculations
      grid_points = generate_calculation_grid
      
      # Calculate blast effects at each point
      grid_points.each do |point|
        blast_pressure = calculate_blast_pressure(point[:distance], point[:angle])
        
        next if blast_pressure < 100 # Skip negligible pressures (<100 Pa)
        
        create_blast_calculation(point, blast_pressure)
      end
      
      # Generate damage zones
      generate_damage_zones!
      
      # Calculate structural damage
      calculate_structural_damage!
      
      update!(calculation_status: 'completed')
      
    rescue StandardError => e
      update!(
        calculation_status: 'failed',
        calculation_warnings: "Calculation failed: #{e.message}"
      )
      raise
    end
  end
  
  # Baker-Strehlow-Tang flame speed calculation
  def calculate_turbulent_flame_speed
    # Base laminar flame speed
    base_flame_speed = laminar_flame_speed || calculate_laminar_flame_speed
    
    # Baker-Strehlow-Tang acceleration factors
    reactivity_factor = BST_REACTIVITY[reactivity_index || 2][:flame_speed_factor]
    
    # Congestion and confinement effects
    congestion_effect = 1.0 + (congestion_factor || 0.1) * 10.0
    confinement_effect = 1.0 + (confinement_factor || 0.1) * 5.0
    
    # Obstacle density effect
    obstacle_effect = 1.0 + (obstacle_density || 0.01) * 50.0
    
    # Combined turbulent flame speed
    turbulent_speed = base_flame_speed * reactivity_factor * 
                     congestion_effect * confinement_effect * obstacle_effect
    
    # Apply upper limit for physical realism
    max_speed = SOUND_SPEED_STP * 0.8 # Max 80% of sound speed for deflagration
    
    update!(turbulent_flame_speed: [turbulent_speed, max_speed].min)
    self.turbulent_flame_speed
  end
  
  # Calculate laminar flame speed if not provided
  def calculate_laminar_flame_speed
    # Correlation for hydrocarbon-air mixtures
    # Based on equivalence ratio and chemical properties
    
    equivalence_ratio = calculate_equivalence_ratio
    
    # Base flame speed at stoichiometric conditions (empirical)
    if chemical.name.downcase.include?('methane')
      base_speed = 0.375 # m/s for methane
    elsif chemical.name.downcase.include?('propane')
      base_speed = 0.43 # m/s for propane
    elsif chemical.name.downcase.include?('hydrogen')
      base_speed = 2.9 # m/s for hydrogen
    else
      # Generic hydrocarbon estimate
      base_speed = 0.4
    end
    
    # Adjust for equivalence ratio
    if equivalence_ratio < 1.0
      # Lean mixture
      flame_speed = base_speed * (2.0 * equivalence_ratio - equivalence_ratio**2)
    else
      # Rich mixture
      flame_speed = base_speed * (2.0 - equivalence_ratio)
    end
    
    # Temperature and pressure corrections
    temp_factor = (ambient_temperature / 298.15)**1.75
    pressure_factor = (ambient_pressure / 101325.0)**(-0.16)
    
    flame_speed * temp_factor * pressure_factor
  end
  
  # Calculate TNT equivalent mass using efficiency method
  def calculate_tnt_equivalent
    # Baker-Strehlow-Tang efficiency factors based on congestion and confinement
    base_efficiency = case reactivity_index || 2
                     when 1 then 0.03  # Low reactivity
                     when 2 then 0.05  # Moderate reactivity
                     when 3 then 0.08  # High reactivity
                     when 4 then 0.12  # Very high reactivity
                     when 5 then 0.18  # Extremely high reactivity
                     when 6 then 0.25  # Detonable
                     end
    
    # Adjust for congestion and confinement
    congestion_multiplier = 1.0 + (congestion_factor || 0.1) * 2.0
    confinement_multiplier = 1.0 + (confinement_factor || 0.1) * 1.5
    
    total_efficiency = base_efficiency * congestion_multiplier * confinement_multiplier
    total_efficiency = [total_efficiency, 0.5].min # Cap at 50% efficiency
    
    # Calculate TNT equivalent
    combustible_mass = cloud_mass * flammable_fraction
    chemical_energy = combustible_mass * (heat_of_combustion || chemical.heat_of_combustion || 45e6)
    
    tnt_equiv = (chemical_energy * total_efficiency) / TNT_HEAT_COMBUSTION
    
    update!(
      efficiency_factor: total_efficiency,
      tnt_equivalent_mass: tnt_equiv
    )
    
    tnt_equiv
  end
  
  # Multi-energy blast model for overpressure calculation
  def calculate_blast_pressure(distance, angle = 0)
    return 0.0 if distance <= 0
    
    # Get TNT equivalent if not calculated
    tnt_mass = tnt_equivalent_mass || calculate_tnt_equivalent
    return 0.0 if tnt_mass <= 0
    
    # Scaled distance calculation
    scaled_distance = distance / (tnt_mass**(1.0/3.0))
    
    # Multi-energy model overpressure calculation
    # Based on empirical correlations from Baker et al.
    
    if scaled_distance < 1.0
      # Very close - use simplified model
      overpressure = ambient_pressure * (1.0 / scaled_distance**3)
    elsif scaled_distance < 10.0
      # Intermediate range - use Kingery-Bulmash equations
      overpressure = calculate_kingery_bulmash_pressure(scaled_distance)
    else
      # Far field - use acoustic approximation
      overpressure = calculate_acoustic_pressure(scaled_distance, tnt_mass)
    end
    
    # Apply directional effects if significant asymmetry
    directional_factor = calculate_directional_factor(angle)
    overpressure *= directional_factor
    
    # Apply ground reflection enhancement
    ground_factor = calculate_ground_reflection_factor(distance)
    overpressure *= ground_factor
    
    # Apply atmospheric attenuation
    atm_factor = calculate_atmospheric_attenuation(distance)
    overpressure *= atm_factor
    
    overpressure
  end
  
  # Kingery-Bulmash overpressure correlation
  def calculate_kingery_bulmash_pressure(scaled_distance)
    z = scaled_distance
    
    # Kingery-Bulmash correlation for side-on overpressure
    # P/P0 = f(Z) where Z is scaled distance
    
    u = Math.log10(z)
    
    if z <= 0.955
      a0, a1, a2, a3, a4, a5, a6 = [2.4586, -0.3896, 0.3015, -0.0758, 0.0076, -0.0004, 0.0000]
    elsif z <= 40.0
      a0, a1, a2, a3, a4, a5, a6 = [0.2681, -1.6924, -0.1128, 0.0481, -0.0105, 0.0011, -0.0000]
    else
      a0, a1, a2, a3, a4, a5, a6 = [-3.3429, -1.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000]
    end
    
    log_pressure = a0 + a1*u + a2*u**2 + a3*u**3 + a4*u**4 + a5*u**5 + a6*u**6
    pressure_ratio = 10**log_pressure
    
    ambient_pressure * pressure_ratio
  end
  
  # Acoustic approximation for far-field
  def calculate_acoustic_pressure(scaled_distance, tnt_mass)
    # For large scaled distances, use acoustic wave approximation
    # P = (ρ * c² * W^(1/3)) / (4π * R²)
    
    air_density = ambient_pressure / (R_SPECIFIC_AIR * ambient_temperature)
    sound_speed = Math.sqrt(GAMMA_AIR * R_SPECIFIC_AIR * ambient_temperature)
    
    energy = tnt_mass * TNT_HEAT_COMBUSTION * (efficiency_factor || 0.05)
    distance = scaled_distance * (tnt_mass**(1.0/3.0))
    
    pressure = (air_density * sound_speed**2 * (energy**(1.0/3.0))) / (4 * Math::PI * distance**2)
    
    [pressure, 50.0].max # Minimum 50 Pa for numerical stability
  end
  
  # Calculate arrival time of blast wave
  def calculate_arrival_time(distance)
    return 0.0 if distance <= 0
    
    # For close distances, use shock wave speed
    # For far distances, use sound speed
    
    tnt_mass = tnt_equivalent_mass || calculate_tnt_equivalent
    scaled_distance = distance / (tnt_mass**(1.0/3.0))
    
    if scaled_distance < 10.0
      # Shock wave regime
      overpressure = calculate_blast_pressure(distance)
      mach_number = calculate_mach_number(overpressure)
      shock_speed = mach_number * Math.sqrt(GAMMA_AIR * R_SPECIFIC_AIR * ambient_temperature)
      distance / shock_speed
    else
      # Acoustic regime
      sound_speed = Math.sqrt(GAMMA_AIR * R_SPECIFIC_AIR * ambient_temperature)
      distance / sound_speed
    end
  end
  
  # Calculate Mach number from overpressure
  def calculate_mach_number(overpressure)
    pressure_ratio = (ambient_pressure + overpressure) / ambient_pressure
    
    # Rankine-Hugoniot relation for shock Mach number
    mach_squared = ((GAMMA_AIR + 1) * pressure_ratio + (GAMMA_AIR - 1)) / (2 * GAMMA_AIR)
    Math.sqrt([mach_squared, 1.0].max)
  end
  
  # Generate calculation grid
  def generate_calculation_grid
    points = []
    max_dist = max_calculation_distance
    resolution = calculation_resolution
    sectors = calculation_sectors
    
    # Radial grid
    (resolution..max_dist).step(resolution) do |distance|
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
  
  # Create blast calculation record
  def create_blast_calculation(point, peak_pressure)
    arrival_time = calculate_arrival_time(point[:distance])
    mach_number = calculate_mach_number(peak_pressure)
    
    # Calculate reflected pressure (factor of 2-8 depending on angle)
    reflected_pressure = peak_pressure * 2.5 # Simplified normal reflection
    
    # Calculate dynamic pressure
    dynamic_pressure = 0.5 * GAMMA_AIR * peak_pressure * mach_number**2
    
    # Calculate impulse (simplified)
    positive_duration = calculate_positive_duration(point[:distance])
    impulse = peak_pressure * positive_duration * 0.5 # Triangular approximation
    
    # Damage assessment
    damage_category = assess_damage_category(peak_pressure)
    lethality_prob = calculate_lethality_probability(peak_pressure)
    
    blast_calculations.create!(
      distance_from_ignition: point[:distance],
      angle_from_ignition: point[:angle],
      latitude: point[:lat],
      longitude: point[:lon],
      peak_overpressure: peak_pressure,
      side_on_pressure: peak_pressure,
      reflected_pressure: reflected_pressure,
      dynamic_pressure: dynamic_pressure,
      total_pressure: peak_pressure + dynamic_pressure,
      arrival_time: arrival_time,
      positive_duration: positive_duration,
      specific_impulse_positive: impulse,
      wave_speed: Math.sqrt(GAMMA_AIR * R_SPECIFIC_AIR * ambient_temperature) * mach_number,
      mach_number: mach_number,
      damage_category: damage_category,
      lethality_probability: lethality_prob,
      injury_probability: calculate_injury_probability(peak_pressure),
      ground_reflection_factor: calculate_ground_reflection_factor(point[:distance]),
      atmospheric_attenuation: calculate_atmospheric_attenuation(point[:distance]),
      line_of_sight: true # Simplified - assume clear line of sight
    )
  end
  
  # Generate damage zones based on pressure thresholds
  def generate_damage_zones!
    DAMAGE_THRESHOLDS.each do |damage_type, threshold_pressure|
      # Find maximum radius for this threshold
      max_radius = find_pressure_radius(threshold_pressure)
      next if max_radius <= 0
      
      # Create zone geometry (simplified circular)
      zone_area = Math::PI * max_radius**2
      
      # Estimate population in zone (placeholder)
      pop_density = 1000 # people per km²
      estimated_population = (zone_area / 1e6) * pop_density
      
      explosion_zones.create!(
        overpressure_threshold: threshold_pressure,
        zone_type: damage_type,
        damage_description: describe_damage_level(damage_type),
        max_radius: max_radius,
        zone_area: zone_area,
        zone_area_km2: zone_area / 1e6,
        estimated_population_affected: estimated_population.round,
        evacuation_required: threshold_pressure >= DAMAGE_THRESHOLDS['structural_damage'],
        evacuation_radius: max_radius * 1.2, # 20% safety margin
        protective_actions: generate_protective_actions(damage_type).to_json
      )
    end
  end
  
  private
  
  def validate_explosion_parameters!
    raise ArgumentError, "Invalid cloud mass" if cloud_mass <= 0
    raise ArgumentError, "Invalid flammability limits" if lower_flammability_limit >= upper_flammability_limit
    raise ArgumentError, "Invalid temperature" if ambient_temperature <= 0
    raise ArgumentError, "Invalid pressure" if ambient_pressure <= 0
  end
  
  def calculate_explosion_characteristics!
    # Calculate basic explosion parameters
    self.stoichiometric_concentration = calculate_stoichiometric_concentration
    self.laminar_flame_speed = calculate_laminar_flame_speed
    self.turbulent_flame_speed = calculate_turbulent_flame_speed
    self.tnt_equivalent_mass = calculate_tnt_equivalent
    
    # Estimate maximum overpressure at close range
    if tnt_equivalent_mass > 0
      close_distance = (tnt_equivalent_mass**(1.0/3.0)) * 2.0 # 2 scaled distance units
      self.maximum_overpressure = calculate_blast_pressure(close_distance)
    end
    
    save!
  end
  
  def calculate_equivalence_ratio
    # Simplified calculation assuming stoichiometric conditions
    # φ = (F/A) / (F/A)_stoichiometric
    1.0 # Assume stoichiometric for simplicity
  end
  
  def flammable_fraction
    # Fraction of cloud mass that is within flammable limits
    # Simplified assumption - in reality this would require concentration distribution
    0.1 # Assume 10% of cloud is flammable
  end
  
  def calculate_stoichiometric_concentration
    # Calculate stoichiometric concentration for combustion
    # CxHy + (x + y/4)O2 → xCO2 + (y/2)H2O
    
    if chemical.formula.present?
      # Parse chemical formula to get C and H atoms
      # Simplified - assume typical hydrocarbon
      4.76 # vol% for typical hydrocarbon in air
    else
      # Default assumption
      3.0
    end
  end
  
  def calculate_directional_factor(angle)
    # Wind effects and cloud asymmetry
    if wind_speed && wind_speed > 2.0
      # Downwind enhancement, upwind reduction
      wind_angle = 0 # Assume reference angle for wind direction
      relative_angle = (angle - wind_angle).abs
      
      if relative_angle < 45
        1.2 # Downwind enhancement
      elsif relative_angle > 135
        0.8 # Upwind reduction
      else
        1.0 # Crosswind
      end
    else
      1.0 # No significant directional effects
    end
  end
  
  def calculate_ground_reflection_factor(distance)
    # Ground reflection enhances blast pressure
    # Factor depends on height of explosion and distance
    
    explosion_height = ignition_height || 0
    
    if explosion_height < 10.0 # Low explosion
      1.8 # Strong ground reflection
    elsif explosion_height < 50.0 # Medium height
      1.4 # Moderate reflection
    else
      1.1 # Weak reflection
    end
  end
  
  def calculate_atmospheric_attenuation(distance)
    # Atmospheric absorption and scattering
    # More significant at longer distances
    
    if distance < 1000
      1.0 # No significant attenuation
    elsif distance < 5000
      0.95 # Slight attenuation
    else
      0.9 # Moderate attenuation
    end
  end
  
  def calculate_positive_duration(distance)
    # Positive phase duration of blast wave
    tnt_mass = tnt_equivalent_mass || 1.0
    scaled_distance = distance / (tnt_mass**(1.0/3.0))
    
    # Empirical correlation
    duration_scaled = 0.2 * (1 + scaled_distance / 10.0)
    duration_scaled * (tnt_mass**(1.0/3.0)) / Math.sqrt(GAMMA_AIR * R_SPECIFIC_AIR * ambient_temperature)
  end
  
  def assess_damage_category(pressure)
    case pressure
    when 0...DAMAGE_THRESHOLDS['window_breakage']
      'light'
    when DAMAGE_THRESHOLDS['window_breakage']...DAMAGE_THRESHOLDS['structural_damage']
      'moderate'
    when DAMAGE_THRESHOLDS['structural_damage']...DAMAGE_THRESHOLDS['building_collapse']
      'severe'
    else
      'complete'
    end
  end
  
  def calculate_lethality_probability(pressure)
    # Probit model for blast lethality
    # Pr = -77.1 + 6.91 * ln(P) where P is in Pa
    
    return 0.0 if pressure < 1000 # Below significant injury threshold
    
    probit = -77.1 + 6.91 * Math.log(pressure)
    
    # Convert probit to probability
    # P = 0.5 * (1 + erf((Pr - 5) / sqrt(2)))
    probability = 0.5 * (1 + Math.erf((probit - 5) / Math.sqrt(2)))
    
    [[probability, 0.0].max, 1.0].min
  end
  
  def calculate_injury_probability(pressure)
    # Similar to lethality but with different constants
    return 0.0 if pressure < 500
    
    probit = -46.1 + 4.82 * Math.log(pressure)
    probability = 0.5 * (1 + Math.erf((probit - 5) / Math.sqrt(2)))
    
    [[probability, 0.0].max, 1.0].min
  end
  
  def find_pressure_radius(threshold_pressure)
    # Binary search for radius where pressure equals threshold
    low, high = 1.0, max_calculation_distance
    tolerance = 1.0 # 1 meter tolerance
    
    while (high - low) > tolerance
      mid = (low + high) / 2.0
      pressure = calculate_blast_pressure(mid)
      
      if pressure > threshold_pressure
        low = mid
      else
        high = mid
      end
    end
    
    pressure_at_radius = calculate_blast_pressure(low)
    pressure_at_radius >= threshold_pressure ? low : 0.0
  end
  
  def describe_damage_level(damage_type)
    case damage_type
    when 'window_breakage'
      'Minor damage: window breakage, minor structural damage'
    when 'structural_damage'
      'Moderate damage: significant structural damage, partial building collapse possible'
    when 'building_collapse'
      'Severe damage: major structural failure, building collapse likely'
    when 'fatality_threshold'
      'Life-threatening: high probability of serious injury or death'
    when 'total_destruction'
      'Complete destruction: total structural failure, near-certain fatality'
    else
      'Damage level unknown'
    end
  end
  
  def generate_protective_actions(damage_type)
    case damage_type
    when 'window_breakage'
      ['Stay away from windows', 'Shelter indoors']
    when 'structural_damage'
      ['Evacuate immediately', 'Seek sturdy shelter', 'Avoid damaged buildings']
    when 'building_collapse', 'fatality_threshold', 'total_destruction'
      ['Immediate evacuation required', 'Emergency medical response', 'Structural inspection needed']
    else
      ['Monitor situation', 'Follow emergency instructions']
    end
  end
  
  def calculate_structural_damage!
    # Calculate damage to buildings in the area
    # This would integrate with the buildings table in a full implementation
    # For now, create representative damage assessments
    
    buildings_in_area = Building.joins(:map_layer)
                              .where('ST_DWithin(ST_Point(longitude, latitude), ST_Point(?, ?), ?)',
                                    longitude, latitude, max_calculation_distance)
    
    buildings_in_area.find_each do |building|
      distance = calculate_distance_to_building(building)
      pressure = calculate_blast_pressure(distance)
      
      next if pressure < 100 # Skip negligible effects
      
      create_structural_damage_assessment(building, pressure, distance)
    end
  rescue StandardError => e
    # Buildings table might not exist or have spatial functions
    Rails.logger.warn("Could not calculate structural damage: #{e.message}")
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
  
  def create_structural_damage_assessment(building, pressure, distance)
    damage_state = assess_damage_category(pressure)
    damage_prob = calculate_damage_probability(pressure, building.building_type)
    
    structural_damages.create!(
      building: building,
      structure_type: building.building_type,
      construction_type: infer_construction_type(building),
      structure_height: building.height,
      structure_area: building.area,
      incident_overpressure: pressure,
      damage_state: damage_state,
      damage_probability: damage_prob,
      fatality_probability: calculate_lethality_probability(pressure),
      serious_injury_probability: calculate_injury_probability(pressure),
      search_rescue_required: damage_state.in?(['severe', 'complete']),
      medical_response_required: pressure >= DAMAGE_THRESHOLDS['structural_damage'],
      structural_inspection_required: pressure >= DAMAGE_THRESHOLDS['window_breakage']
    )
  end
  
  def calculate_damage_probability(pressure, building_type)
    # Vulnerability functions for different building types
    base_prob = case assess_damage_category(pressure)
                when 'light' then 0.1
                when 'moderate' then 0.3
                when 'severe' then 0.7
                when 'complete' then 0.95
                else 0.0
                end
    
    # Adjust for building type
    case building_type&.downcase
    when 'residential'
      base_prob * 1.2 # More vulnerable
    when 'industrial'
      base_prob * 0.8 # More robust
    when 'commercial'
      base_prob * 1.0 # Average
    else
      base_prob
    end
  end
  
  def infer_construction_type(building)
    # Simple inference based on building type and height
    case building.building_type&.downcase
    when 'residential'
      building.height && building.height > 20 ? 'concrete' : 'wood_frame'
    when 'industrial'
      'steel_frame'
    when 'commercial'
      building.height && building.height > 50 ? 'steel_frame' : 'concrete'
    else
      'unknown'
    end
  end
end