# Blast Calculation model for storing spatial blast pressure calculations
# Represents blast effects at specific locations from vapor cloud explosions
class BlastCalculation < ApplicationRecord
  belongs_to :vapor_cloud_explosion
  
  # Delegate to explosion for convenience
  delegate :dispersion_scenario, :chemical, to: :vapor_cloud_explosion
  
  # Validation
  validates :distance_from_ignition, :peak_overpressure, :arrival_time,
            presence: true, numericality: { greater_than: 0 }
  validates :latitude, :longitude, presence: true, numericality: true
  validates :damage_category, inclusion: { in: %w[light moderate severe complete] }
  validates :lethality_probability, :injury_probability,
            numericality: { in: 0..1 }, allow_nil: true
  
  # Scopes for analysis
  scope :by_damage_level, ->(level) { where(damage_category: level) }
  scope :high_lethality, -> { where('lethality_probability > ?', 0.5) }
  scope :within_radius, ->(radius) { where('distance_from_ignition <= ?', radius) }
  scope :ordered_by_distance, -> { order(:distance_from_ignition) }
  scope :lethal_zone, -> { where('peak_overpressure >= ?', VaporCloudExplosion::DAMAGE_THRESHOLDS['fatality_threshold']) }
  scope :damage_zone, -> { where('peak_overpressure >= ?', VaporCloudExplosion::DAMAGE_THRESHOLDS['structural_damage']) }
  
  # Constants for calculations
  PROB_SCALE_FACTORS = {
    'lethality' => { a: -77.1, b: 6.91 },
    'injury' => { a: -46.1, b: 4.82 },
    'eardrum' => { a: -15.6, b: 1.93 }
  }.freeze
  
  # Calculate blast wave parameters
  def calculate_wave_parameters!
    # Update wave speed based on Mach number
    if mach_number.present? && mach_number > 1.0
      sound_speed = Math.sqrt(1.4 * 287.0 * (vapor_cloud_explosion.ambient_temperature || 288.15))
      self.wave_speed = sound_speed * mach_number
    end
    
    # Calculate impulse if duration is available
    if positive_duration.present? && peak_overpressure.present?
      self.specific_impulse_positive = peak_overpressure * positive_duration * 0.5
    end
    
    # Update total pressure
    self.total_pressure = (side_on_pressure || peak_overpressure) + (dynamic_pressure || 0)
    
    save! if changed?
  end
  
  # Enhanced damage assessment
  def assess_structural_damage
    pressure_psi = peak_overpressure * 0.000145038 # Convert Pa to psi
    
    damage_assessment = {
      glass_breakage: pressure_psi >= 0.5,
      window_frames: pressure_psi >= 1.0,
      structural_damage: pressure_psi >= 3.0,
      serious_structural: pressure_psi >= 5.0,
      building_collapse: pressure_psi >= 7.0,
      total_destruction: pressure_psi >= 25.0
    }
    
    # Determine overall damage state
    if damage_assessment[:total_destruction]
      'complete'
    elsif damage_assessment[:building_collapse]
      'severe'
    elsif damage_assessment[:structural_damage]
      'moderate'
    elsif damage_assessment[:glass_breakage]
      'light'
    else
      'negligible'
    end
  end
  
  # Calculate human casualty probabilities using probit models
  def calculate_casualty_probabilities
    results = {}
    
    PROB_SCALE_FACTORS.each do |casualty_type, factors|
      if peak_overpressure >= 100 # Minimum pressure for effects
        probit = factors[:a] + factors[:b] * Math.log(peak_overpressure)
        probability = probit_to_probability(probit)
        results[casualty_type] = probability
      else
        results[casualty_type] = 0.0
      end
    end
    
    # Update model attributes
    self.lethality_probability = results['lethality']
    self.injury_probability = results['injury']
    
    results
  end
  
  # Calculate missile/debris hazard
  def calculate_missile_hazard
    # Fragment velocity from pressure impulse
    if specific_impulse_positive.present? && peak_overpressure >= 3500 # 0.5 psi threshold
      # Simplified debris velocity calculation
      impulse_momentum = specific_impulse_positive * 1.0 # kg·m/s per unit area
      fragment_mass = 0.1 # kg (typical glass fragment)
      fragment_velocity = impulse_momentum / fragment_mass
      
      # Range calculation for fragments
      launch_angle = 45 * Math::PI / 180 # Optimal angle
      gravity = 9.81
      
      fragment_range = (fragment_velocity**2 * Math.sin(2 * launch_angle)) / gravity
      
      {
        debris_generated: true,
        fragment_velocity: fragment_velocity,
        maximum_range: fragment_range,
        hazard_level: classify_missile_hazard(fragment_velocity)
      }
    else
      {
        debris_generated: false,
        fragment_velocity: 0,
        maximum_range: 0,
        hazard_level: 'none'
      }
    end
  end
  
  # Calculate thermal effects from blast (if any)
  def calculate_thermal_effects
    # Blast waves can generate some thermal effects through compression
    if peak_overpressure >= 20000 # 20 kPa threshold for significant heating
      # Adiabatic compression heating
      pressure_ratio = (vapor_cloud_explosion.ambient_pressure + peak_overpressure) / 
                      vapor_cloud_explosion.ambient_pressure
      
      # Temperature rise from compression
      gamma = 1.4 # Heat capacity ratio for air
      temp_ratio = pressure_ratio**((gamma - 1) / gamma)
      temp_rise = (vapor_cloud_explosion.ambient_temperature || 288.15) * (temp_ratio - 1)
      
      {
        temperature_rise: temp_rise,
        thermal_effect: temp_rise > 50 ? 'significant' : 'minor'
      }
    else
      {
        temperature_rise: 0,
        thermal_effect: 'negligible'
      }
    end
  end
  
  # Assess environmental effects
  def assess_environmental_impact
    impact_level = case peak_overpressure
                  when 0...1000
                    'negligible'
                  when 1000...5000
                    'minor'
                  when 5000...20000
                    'moderate'
                  when 20000...50000
                    'significant'
                  else
                    'severe'
                  end
    
    effects = {
      impact_level: impact_level,
      ground_shock: peak_overpressure >= 10000,
      vegetation_damage: peak_overpressure >= 5000,
      wildlife_impact: peak_overpressure >= 3000,
      soil_disturbance: peak_overpressure >= 15000
    }
    
    # Additional effects based on distance and pressure
    if distance_from_ignition < 100 && peak_overpressure >= 50000
      effects[:crater_formation] = true
      effects[:subsurface_effects] = true
    end
    
    effects
  end
  
  # Calculate evacuation timing requirements
  def calculate_evacuation_requirements
    # Time available for evacuation before blast arrival
    warning_time = [arrival_time - 30, 0].max # 30 seconds for warning systems
    
    evacuation_distance = case damage_category
                          when 'complete', 'severe'
                            distance_from_ignition * 2.0 # Move to safe distance
                          when 'moderate'
                            distance_from_ignition * 1.5
                          else
                            distance_from_ignition * 1.2
                          end
    
    # Assume average evacuation speed of 2 m/s (walking quickly)
    evacuation_time_needed = evacuation_distance / 2.0
    
    {
      warning_time_available: warning_time,
      evacuation_time_needed: evacuation_time_needed,
      evacuation_feasible: warning_time >= evacuation_time_needed,
      recommended_action: determine_recommended_action(warning_time, evacuation_time_needed)
    }
  end
  
  # Check if point is in shadow zone (blast wave blocked)
  def in_shadow_zone?
    # Simplified shadow zone calculation
    # Would need detailed terrain and obstacle data for accuracy
    return false unless line_of_sight == false
    
    # If not line of sight, pressure should be reduced
    true
  end
  
  # Calculate pressure reduction due to barriers
  def calculate_barrier_effects(barrier_height: nil, barrier_distance: nil)
    return 1.0 unless barrier_height && barrier_distance
    
    # Simplified barrier shielding calculation
    if barrier_distance < distance_from_ignition
      # Calculate diffraction effects
      fresnel_number = calculate_fresnel_number(barrier_height, barrier_distance)
      
      if fresnel_number > 0
        # Positive Fresnel number - shadow zone
        reduction_factor = 1.0 / (1.0 + fresnel_number)
      else
        # Negative Fresnel number - no significant shielding
        reduction_factor = 1.0
      end
    else
      reduction_factor = 1.0
    end
    
    reduction_factor
  end
  
  # Generate detailed blast effects summary
  def blast_effects_summary
    effects = {
      location: {
        distance: distance_from_ignition,
        bearing: angle_from_ignition,
        coordinates: [latitude, longitude]
      },
      blast_parameters: {
        peak_pressure: peak_overpressure,
        arrival_time: arrival_time,
        duration: positive_duration,
        impulse: specific_impulse_positive,
        mach_number: mach_number
      },
      damage_assessment: {
        category: damage_category,
        structural: assess_structural_damage,
        missiles: calculate_missile_hazard,
        thermal: calculate_thermal_effects
      },
      human_effects: {
        lethality: lethality_probability,
        injury: injury_probability,
        evacuation: calculate_evacuation_requirements
      },
      environmental: assess_environmental_impact
    }
    
    effects
  end
  
  # Export data for GIS analysis
  def to_geojson
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      properties: {
        distance: distance_from_ignition,
        peak_overpressure: peak_overpressure,
        damage_category: damage_category,
        lethality_probability: lethality_probability,
        arrival_time: arrival_time,
        mach_number: mach_number,
        total_pressure: total_pressure
      }
    }
  end
  
  private
  
  # Convert probit value to probability
  def probit_to_probability(probit)
    # Probit = Φ^(-1)(P) where Φ is standard normal CDF
    # P = Φ(probit) = 0.5 * (1 + erf(probit/sqrt(2)))
    
    probability = 0.5 * (1 + Math.erf(probit / Math.sqrt(2)))
    [[probability, 0.0].max, 1.0].min
  end
  
  # Classify missile hazard level
  def classify_missile_hazard(velocity)
    case velocity
    when 0...10
      'low'
    when 10...25
      'moderate'
    when 25...50
      'high'
    else
      'extreme'
    end
  end
  
  # Determine recommended protective action
  def determine_recommended_action(warning_time, evacuation_time)
    if warning_time >= evacuation_time * 2
      'evacuate_immediately'
    elsif warning_time >= evacuation_time
      'evacuate_if_possible'
    elsif damage_category.in?(['severe', 'complete'])
      'take_immediate_shelter'
    else
      'shelter_in_place'
    end
  end
  
  # Calculate Fresnel number for barrier diffraction
  def calculate_fresnel_number(barrier_height, barrier_distance)
    # Simplified Fresnel number calculation
    # F = h * sqrt(2 / (λ * d1 * d2 / (d1 + d2)))
    # Where h = barrier height, λ = wavelength, d1 = source distance, d2 = receiver distance
    
    # Assume blast wave frequency around 10 Hz
    frequency = 10.0
    sound_speed = Math.sqrt(1.4 * 287.0 * (vapor_cloud_explosion.ambient_temperature || 288.15))
    wavelength = sound_speed / frequency
    
    d1 = barrier_distance
    d2 = distance_from_ignition - barrier_distance
    
    return 0 if d2 <= 0
    
    barrier_height * Math.sqrt(2 / (wavelength * d1 * d2 / (d1 + d2)))
  end
end