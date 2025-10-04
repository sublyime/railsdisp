# Thermal Calculation model for storing spatial thermal radiation calculations
# Represents heat flux effects at specific locations from thermal radiation incidents
class ThermalCalculation < ApplicationRecord
  belongs_to :thermal_radiation_incident
  
  # Delegate to incident for convenience
  delegate :dispersion_scenario, :chemical, :incident_type, to: :thermal_radiation_incident
  
  # Validation
  validates :distance_from_source, :incident_heat_flux, :view_factor,
            presence: true, numericality: { greater_than: 0 }
  validates :latitude, :longitude, presence: true, numericality: true
  validates :thermal_damage_level, inclusion: { 
    in: %w[none discomfort pain injury severe_burn lethality] 
  }
  validates :burn_probability, :lethality_probability,
            numericality: { in: 0..1 }, allow_nil: true
  validates :atmospheric_transmittance, numericality: { in: 0..1 }, allow_nil: true
  
  # Scopes for analysis
  scope :by_damage_level, ->(level) { where(thermal_damage_level: level) }
  scope :high_heat_flux, -> { where('incident_heat_flux > ?', 25000) } # >25 kW/m²
  scope :within_radius, ->(radius) { where('distance_from_source <= ?', radius) }
  scope :ordered_by_distance, -> { order(:distance_from_source) }
  scope :lethal_zone, -> { where('incident_heat_flux >= ?', 37500) } # 37.5 kW/m²
  scope :injury_zone, -> { where('incident_heat_flux >= ?', 12500) } # 12.5 kW/m²
  scope :pain_zone, -> { where('incident_heat_flux >= ?', 5000) } # 5 kW/m²
  
  # Heat flux severity classifications
  SEVERITY_LEVELS = {
    'minimal' => { min: 0, max: 1000, description: 'No significant effects' },
    'low' => { min: 1000, max: 2500, description: 'Discomfort after prolonged exposure' },
    'moderate' => { min: 2500, max: 5000, description: 'Pain threshold' },
    'high' => { min: 5000, max: 12500, description: 'Injury potential' },
    'severe' => { min: 12500, max: 25000, description: 'Serious burns likely' },
    'extreme' => { min: 25000, max: 37500, description: 'Severe burns, high injury risk' },
    'lethal' => { min: 37500, max: Float::INFINITY, description: 'Potentially lethal' }
  }.freeze
  
  # Calculate detailed thermal effects
  def calculate_thermal_effects!
    # Update thermal dose if duration is available
    if thermal_radiation_incident.fire_duration.present?
      calculate_thermal_dose_effects!
    end
    
    # Calculate protective equipment requirements
    calculate_protective_requirements!
    
    # Calculate evacuation timing
    calculate_evacuation_timing!
    
    # Update absorbed and net heat flux
    calculate_heat_absorption_effects!
    
    save! if changed?
  end
  
  # Calculate thermal dose and injury progression
  def calculate_thermal_dose_effects!
    duration = thermal_radiation_incident.fire_duration
    
    # Thermal dose calculation: Φ = q"^(4/3) * t
    self.thermal_dose = (incident_heat_flux ** (4.0/3.0)) * duration
    
    # Calculate time to various thermal effects using Stoll curve
    self.time_to_pain = calculate_time_to_effect('pain')
    self.time_to_2nd_degree_burn = calculate_time_to_effect('second_degree_burn')
    self.time_to_death = calculate_time_to_effect('lethality')
    
    # Update probabilities based on actual exposure
    actual_exposure = [duration, time_to_death || Float::INFINITY].min
    self.burn_probability = calculate_burn_probability(actual_exposure)
    self.lethality_probability = calculate_lethality_probability(actual_exposure)
  end
  
  # Calculate time to specific thermal effect using Stoll curve
  def calculate_time_to_effect(effect_type)
    return Float::INFINITY if incident_heat_flux < 1000
    
    # Stoll curve parameters for different effects
    stoll_parameters = {
      'pain' => { threshold: 1050, exponent: 0.667 }, # (J/m²)^0.667
      'second_degree_burn' => { threshold: 1600, exponent: 0.667 },
      'lethality' => { threshold: 3200, exponent: 0.667 }
    }
    
    params = stoll_parameters[effect_type]
    return Float::INFINITY unless params
    
    # Stoll equation: (q" × t)^n = constant
    # Solving for t: t = (constant / q")^(1/n)
    
    flux_kw = incident_heat_flux / 1000.0 # Convert to kW/m²
    time_seconds = (params[:threshold] / flux_kw) ** (1.0 / params[:exponent])
    
    # Apply safety factors and physiological variations
    safety_factor = case effect_type
                   when 'pain' then 0.8 # Conservative for pain
                   when 'second_degree_burn' then 1.0 # Standard
                   when 'lethality' then 1.5 # Conservative for lethality
                   else 1.0
                   end
    
    time_seconds * safety_factor
  end
  
  # Calculate burn probability based on exposure time
  def calculate_burn_probability(exposure_time)
    return 0.0 if incident_heat_flux < 2500 # Below burn threshold
    
    # Probit model for burn injury
    # Based on Eisenberg correlation
    dose = (incident_heat_flux / 1000.0) ** (4.0/3.0) * exposure_time
    
    if dose > 0
      probit = -36.38 + 2.56 * Math.log(dose)
      probit_to_probability(probit)
    else
      0.0
    end
  end
  
  # Calculate lethality probability
  def calculate_lethality_probability(exposure_time)
    return 0.0 if incident_heat_flux < 10000 # Below significant lethality threshold
    
    # Enhanced probit model for lethality
    dose = (incident_heat_flux / 1000.0) ** (4.0/3.0) * exposure_time
    
    if dose > 100 # Minimum dose for lethality consideration
      probit = -36.38 + 2.56 * Math.log(dose)
      # Apply additional factor for lethality vs burns
      lethality_probit = probit - 2.0 # More conservative for lethality
      probit_to_probability(lethality_probit)
    else
      0.0
    end
  end
  
  # Calculate heat absorption effects
  def calculate_heat_absorption_effects!
    # Account for surface properties and atmospheric effects
    
    # Atmospheric absorption
    if atmospheric_transmittance.present?
      self.absorbed_heat_flux = incident_heat_flux * atmospheric_transmittance
    else
      self.absorbed_heat_flux = incident_heat_flux * 0.9 # Default 90% transmission
    end
    
    # Additional humidity absorption
    if thermal_radiation_incident.relative_humidity.present?
      humidity = thermal_radiation_incident.relative_humidity
      if humidity > 0.5
        humidity_factor = 1.0 - (humidity - 0.5) * 0.2
        self.absorbed_heat_flux *= humidity_factor
      end
    end
    
    # Calculate net heat flux (after reflection)
    surface_reflectivity = 0.1 # Assume 10% reflectivity for human skin/clothing
    self.net_heat_flux = absorbed_heat_flux * (1.0 - surface_reflectivity)
    
    # Calculate path length for atmospheric effects
    self.path_length = distance_from_source
    
    # Additional humidity absorption effects
    if thermal_radiation_incident.relative_humidity.present?
      self.humidity_absorption = calculate_humidity_absorption
    end
  end
  
  # Calculate protective equipment requirements
  def calculate_protective_requirements!
    requirements = []
    
    case incident_heat_flux
    when 0...2500
      requirements << 'No special protection required'
    when 2500...5000
      requirements << 'Long sleeves and pants recommended'
      requirements << 'Eye protection'
    when 5000...12500
      requirements << 'Fire-resistant clothing required'
      requirements << 'Face shield or helmet'
      requirements << 'Insulated gloves'
    when 12500...25000
      requirements << 'Proximity suit required'
      requirements << 'Self-contained breathing apparatus'
      requirements << 'Thermal insulation'
    when 25000...37500
      requirements << 'Entry suit with cooling'
      requirements << 'Full thermal protection'
      requirements << 'Limited exposure time'
    else
      requirements << 'Entry prohibited'
      requirements << 'Remote operations only'
    end
    
    # Additional requirements based on incident type
    case thermal_radiation_incident.incident_type
    when 'bleve_fireball'
      requirements << 'Blast protection considerations'
    when 'jet_fire'
      requirements << 'Wind direction awareness'
    when 'pool_fire'
      requirements << 'Ground-level hazard awareness'
    end
    
    self.protective_measures = requirements.to_json
  end
  
  # Calculate evacuation timing requirements
  def calculate_evacuation_timing!
    # Time available before thermal effects
    warning_time = [time_to_pain || Float::INFINITY, 30.0].min # Max 30 seconds warning
    
    # Distance to safe zone (below 2.5 kW/m²)
    safe_distance = calculate_safe_distance
    evacuation_distance = safe_distance - distance_from_source
    
    if evacuation_distance > 0
      # Need to move to safety
      evacuation_speed = 2.0 # m/s average evacuation speed
      evacuation_time_needed = evacuation_distance / evacuation_speed
      
      evacuation_feasible = warning_time >= evacuation_time_needed
      
      if evacuation_feasible
        recommended_action = 'evacuate_immediately'
      else
        recommended_action = case thermal_damage_level
                            when 'none', 'discomfort'
                              'shelter_in_place'
                            when 'pain'
                              'seek_immediate_shelter'
                            else
                              'emergency_shelter'
                            end
      end
    else
      # Already in safe zone
      evacuation_feasible = true
      recommended_action = 'monitor_situation'
    end
    
    {
      warning_time: warning_time,
      evacuation_time_needed: evacuation_distance > 0 ? evacuation_distance / 2.0 : 0,
      evacuation_feasible: evacuation_feasible,
      recommended_action: recommended_action
    }
  end
  
  # Calculate safe distance (below discomfort threshold)
  def calculate_safe_distance
    # Calculate distance where heat flux drops to 2.5 kW/m² (discomfort threshold)
    target_flux = 2500.0
    incident = thermal_radiation_incident
    
    # Use view factor relationship to estimate safe distance
    if incident.surface_emissive_power > 0 && view_factor > 0
      # q" = F * SEP * τ
      # Assuming similar atmospheric transmittance
      required_view_factor = target_flux / (incident.surface_emissive_power * (atmospheric_transmittance || 0.9))
      
      # For spherical source: F = (R/L)² / (1 + (R/L)²)²
      # Solving for L approximately: L ≈ R / sqrt(F) for small F
      
      if incident.incident_type == 'bleve_fireball'
        radius = incident.fire_diameter / 2.0
        estimated_distance = radius / Math.sqrt([required_view_factor, 0.001].max)
      else
        # For other fire types, use empirical factor
        estimated_distance = distance_from_source * Math.sqrt(incident_heat_flux / target_flux)
      end
      
      [estimated_distance, distance_from_source * 2].max # At least 2x current distance
    else
      distance_from_source * 3 # Conservative estimate
    end
  end
  
  # Assess environmental effects of thermal radiation
  def assess_environmental_effects
    effects = {
      vegetation: assess_vegetation_effects,
      structures: assess_structural_effects,
      equipment: assess_equipment_effects,
      secondary_fires: assess_secondary_fire_risk
    }
    
    effects
  end
  
  # Calculate potential for ignition of materials
  def calculate_ignition_potential
    # Ignition temperatures for common materials (°C)
    ignition_temps = {
      'paper' => 230,
      'wood' => 260,
      'plastic' => 200,
      'vegetation' => 280,
      'gasoline' => 280,
      'natural_gas' => 540
    }
    
    # Estimate surface temperature from heat flux
    # Simplified: assume equilibrium temperature
    stefan_boltzmann = 5.67e-8 # W/m²/K⁴
    emissivity = 0.9 # Typical for most materials
    
    # q" = ε * σ * (T⁴ - T_amb⁴)
    # Solving for T: T = ((q"/ε/σ) + T_amb⁴)^0.25
    t_amb = thermal_radiation_incident.ambient_temperature || 288.15
    surface_temp = ((incident_heat_flux / (emissivity * stefan_boltzmann)) + t_amb**4)**0.25
    
    ignition_risks = {}
    ignition_temps.each do |material, temp_c|
      temp_k = temp_c + 273.15
      ignition_risks[material] = surface_temp >= temp_k
    end
    
    {
      surface_temperature: surface_temp,
      ignition_potential: ignition_risks,
      high_risk_materials: ignition_risks.select { |_, ignites| ignites }.keys
    }
  end
  
  # Generate thermal effects summary
  def thermal_effects_summary
    {
      location: {
        distance: distance_from_source,
        bearing: angle_from_source,
        coordinates: [latitude, longitude]
      },
      thermal_parameters: {
        incident_flux: incident_heat_flux,
        absorbed_flux: absorbed_heat_flux,
        net_flux: net_heat_flux,
        view_factor: view_factor,
        thermal_dose: thermal_dose
      },
      human_effects: {
        damage_level: thermal_damage_level,
        burn_probability: burn_probability,
        lethality_probability: lethality_probability,
        time_to_pain: time_to_pain,
        time_to_burns: time_to_2nd_degree_burn
      },
      protective_measures: parse_protective_measures,
      evacuation: calculate_evacuation_timing!,
      ignition_potential: calculate_ignition_potential,
      environmental: assess_environmental_effects
    }
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
        distance: distance_from_source,
        heat_flux: incident_heat_flux,
        damage_level: thermal_damage_level,
        burn_probability: burn_probability,
        thermal_dose: thermal_dose,
        view_factor: view_factor,
        evacuation_required: incident_heat_flux >= 5000
      }
    }
  end
  
  # Calculate thermal dose for specific exposure time
  def thermal_dose_for_exposure(exposure_time)
    (incident_heat_flux ** (4.0/3.0)) * exposure_time
  end
  
  # Calculate skin temperature rise
  def calculate_skin_temperature_rise(exposure_time)
    # Simplified skin heating model
    # Based on Pennes bioheat equation approximation
    
    skin_conductivity = 0.37 # W/m/K
    skin_density = 1000 # kg/m³
    skin_specific_heat = 3600 # J/kg/K
    skin_thickness = 0.002 # m (2mm)
    
    # Thermal diffusivity
    alpha = skin_conductivity / (skin_density * skin_specific_heat)
    
    # Surface heat flux absorbed
    absorbed_flux = net_heat_flux || (incident_heat_flux * 0.9)
    
    # Temperature rise approximation for thin layer
    # ΔT ≈ q" * δ / k
    temp_rise = (absorbed_flux * skin_thickness) / skin_conductivity
    
    # Time-dependent factor for heating
    time_factor = 1 - Math.exp(-exposure_time / (skin_thickness**2 / alpha))
    
    temp_rise * time_factor
  end
  
  # Calculate heat stress index
  def calculate_heat_stress_index
    # Heat stress index based on heat flux and exposure time
    # Used for worker safety assessment
    
    case incident_heat_flux
    when 0...1000
      'no_stress'
    when 1000...2500
      'minimal_stress'
    when 2500...5000
      'moderate_stress'
    when 5000...12500
      'high_stress'
    when 12500...25000
      'severe_stress'
    else
      'extreme_stress'
    end
  end
  
  private
  
  # Convert probit value to probability
  def probit_to_probability(probit)
    probability = 0.5 * (1 + Math.erf(probit / Math.sqrt(2)))
    [[probability, 0.0].max, 1.0].min
  end
  
  # Calculate humidity absorption effects
  def calculate_humidity_absorption
    humidity = thermal_radiation_incident.relative_humidity || 0.5
    
    # Additional absorption due to water vapor
    # Based on path length and humidity
    if path_length && humidity > 0.3
      excess_humidity = humidity - 0.3
      absorption_factor = 1.0 - (excess_humidity * path_length * 1e-4)
      [absorption_factor, 0.7].max # Minimum 70% transmission
    else
      1.0
    end
  end
  
  # Parse protective measures from JSON
  def parse_protective_measures
    if protective_measures.present?
      JSON.parse(protective_measures)
    else
      []
    end
  rescue JSON::ParserError
    []
  end
  
  # Environmental effects assessment methods
  def assess_vegetation_effects
    case incident_heat_flux
    when 0...5000
      'no_effect'
    when 5000...10000
      'leaf_scorching'
    when 10000...20000
      'branch_ignition'
    else
      'tree_ignition'
    end
  end
  
  def assess_structural_effects
    case incident_heat_flux
    when 0...10000
      'no_effect'
    when 10000...25000
      'paint_blistering'
    when 25000...50000
      'material_ignition'
    else
      'structural_damage'
    end
  end
  
  def assess_equipment_effects
    case incident_heat_flux
    when 0...15000
      'no_effect'
    when 15000...30000
      'instrument_damage'
    when 30000...60000
      'equipment_failure'
    else
      'equipment_destruction'
    end
  end
  
  def assess_secondary_fire_risk
    ignition_potential = calculate_ignition_potential
    
    if ignition_potential[:high_risk_materials].any?
      'high_risk'
    elsif incident_heat_flux >= 10000
      'moderate_risk'
    elsif incident_heat_flux >= 5000
      'low_risk'
    else
      'minimal_risk'
    end
  end
end