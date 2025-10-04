# Equipment Thermal Damage model for assessing thermal radiation effects on buildings and equipment
# Links thermal incidents to specific structures and calculates thermal damage
class EquipmentThermalDamage < ApplicationRecord
  belongs_to :thermal_radiation_incident
  belongs_to :building, optional: true
  
  # Delegate to incident and building for convenience
  delegate :dispersion_scenario, :chemical, :incident_type, to: :thermal_radiation_incident
  delegate :latitude, :longitude, :building_type, :height, :area, to: :building, allow_nil: true
  
  # Validation
  validates :equipment_type, :material_type, :incident_heat_flux, presence: true
  validates :equipment_type, inclusion: { 
    in: %w[storage_tank pressure_vessel piping structure vehicle electrical_equipment process_equipment] 
  }
  validates :material_type, inclusion: { 
    in: %w[steel aluminum concrete plastic composite wood fiberglass carbon_steel stainless_steel] 
  }
  validates :construction_standard, inclusion: { 
    in: %w[API650 API620 ASME AISC concrete wood_frame NFPA unknown] 
  }, allow_nil: true
  validates :incident_heat_flux, numericality: { greater_than: 0 }
  validates :damage_state, inclusion: { in: %w[none minor moderate severe failure] }
  validates :failure_probability, numericality: { in: 0..1 }, allow_nil: true
  
  # Scopes for analysis
  scope :by_equipment_type, ->(type) { where(equipment_type: type) }
  scope :by_material_type, ->(type) { where(material_type: type) }
  scope :by_damage_state, ->(state) { where(damage_state: state) }
  scope :high_failure_risk, -> { where('failure_probability > ?', 0.5) }
  scope :structural_failures, -> { where(structural_failure: true) }
  scope :escalation_risks, -> { where(escalation_potential: true) }
  scope :critical_equipment, -> { where(equipment_type: ['storage_tank', 'pressure_vessel']) }
  
  # Material thermal properties (typical values)
  MATERIAL_PROPERTIES = {
    'steel' => {
      thermal_conductivity: 50.0, # W/m/K
      specific_heat: 500.0, # J/kg/K
      density: 7850.0, # kg/m³
      critical_temperature: 773.15, # K (500°C)
      emissivity: 0.8,
      yield_strength_factor: 0.5 # Strength reduction at critical temp
    },
    'aluminum' => {
      thermal_conductivity: 235.0,
      specific_heat: 900.0,
      density: 2700.0,
      critical_temperature: 573.15, # K (300°C)
      emissivity: 0.9,
      yield_strength_factor: 0.3
    },
    'concrete' => {
      thermal_conductivity: 1.7,
      specific_heat: 1000.0,
      density: 2300.0,
      critical_temperature: 673.15, # K (400°C spalling)
      emissivity: 0.95,
      yield_strength_factor: 0.6
    },
    'plastic' => {
      thermal_conductivity: 0.2,
      specific_heat: 1500.0,
      density: 1200.0,
      critical_temperature: 423.15, # K (150°C)
      emissivity: 0.95,
      yield_strength_factor: 0.1
    },
    'wood' => {
      thermal_conductivity: 0.12,
      specific_heat: 1500.0,
      density: 600.0,
      critical_temperature: 533.15, # K (260°C ignition)
      emissivity: 0.9,
      yield_strength_factor: 0.1
    },
    'fiberglass' => {
      thermal_conductivity: 0.04,
      specific_heat: 1000.0,
      density: 2000.0,
      critical_temperature: 573.15, # K (300°C)
      emissivity: 0.9,
      yield_strength_factor: 0.2
    }
  }.freeze
  
  # Equipment vulnerability factors by type
  EQUIPMENT_VULNERABILITY = {
    'storage_tank' => {
      base_vulnerability: 1.0,
      contents_factor: 1.5, # Higher risk if contains flammables
      pressure_factor: 1.2, # Higher risk for pressurized
      isolation_factor: 0.8 # Can be isolated
    },
    'pressure_vessel' => {
      base_vulnerability: 1.3,
      contents_factor: 2.0, # Much higher risk
      pressure_factor: 1.8, # Very high pressure risk
      isolation_factor: 0.7
    },
    'piping' => {
      base_vulnerability: 0.8,
      contents_factor: 1.2,
      pressure_factor: 1.1,
      isolation_factor: 0.9
    },
    'structure' => {
      base_vulnerability: 0.6,
      contents_factor: 1.0,
      pressure_factor: 1.0,
      isolation_factor: 1.0
    },
    'vehicle' => {
      base_vulnerability: 1.1,
      contents_factor: 1.3,
      pressure_factor: 1.0,
      isolation_factor: 0.9
    },
    'electrical_equipment' => {
      base_vulnerability: 1.2,
      contents_factor: 1.0,
      pressure_factor: 1.0,
      isolation_factor: 0.8
    }
  }.freeze
  
  # Calculate comprehensive thermal damage assessment
  def calculate_thermal_damage_assessment!
    # Get material properties
    set_material_properties!
    
    # Calculate thermal exposure effects
    calculate_thermal_exposure!
    
    # Assess damage state and failure probability
    assess_damage_and_failure!
    
    # Calculate economic impacts
    calculate_economic_impacts!
    
    # Assess secondary hazards and escalation potential
    assess_secondary_hazards!
    
    # Determine protective measures required
    determine_protective_measures!
    
    save!
  end
  
  # Set material properties from database
  def set_material_properties!
    props = MATERIAL_PROPERTIES[material_type] || MATERIAL_PROPERTIES['steel']
    
    self.thermal_conductivity ||= props[:thermal_conductivity]
    self.specific_heat ||= props[:specific_heat]
    self.density ||= props[:density]
    self.critical_temperature ||= props[:critical_temperature]
    self.emissivity ||= props[:emissivity]
  end
  
  # Calculate thermal exposure effects
  def calculate_thermal_exposure!
    duration = exposure_duration || thermal_radiation_incident.fire_duration || 300.0
    
    # Calculate surface temperature using heat balance
    self.surface_temperature = calculate_surface_temperature(duration)
    
    # Calculate time to failure
    self.time_to_failure = calculate_time_to_critical_temperature
    
    # Check if critical temperature is exceeded
    critical_temp_exceeded = surface_temperature >= critical_temperature
    
    # Update exposure parameters
    self.exposure_duration = duration
    
    # Calculate thermal stress effects
    calculate_thermal_stress_effects!
  end
  
  # Calculate surface temperature using heat balance equation
  def calculate_surface_temperature(duration)
    # Heat balance: q_incident = q_convection + q_radiation + q_conduction
    # Simplified steady-state approximation for surface temperature
    
    ambient_temp = thermal_radiation_incident.ambient_temperature || 288.15
    
    # Convective heat transfer coefficient (W/m²/K)
    h_conv = calculate_convective_coefficient
    
    # Stefan-Boltzmann constant
    sigma = 5.67e-8 # W/m²/K⁴
    
    # Solve heat balance iteratively
    temp_surface = ambient_temp + 100 # Initial guess
    
    10.times do
      # Heat balance equation:
      # q_incident = h_conv*(T_s - T_amb) + ε*σ*(T_s⁴ - T_amb⁴) + q_conduction
      
      q_convection = h_conv * (temp_surface - ambient_temp)
      q_radiation = emissivity * sigma * (temp_surface**4 - ambient_temp**4)
      q_conduction = calculate_conduction_heat_flux(temp_surface, ambient_temp)
      
      q_total_loss = q_convection + q_radiation + q_conduction
      
      # Adjust temperature
      temp_error = incident_heat_flux - q_total_loss
      temp_surface += temp_error / (h_conv + 4 * emissivity * sigma * temp_surface**3)
      
      break if temp_error.abs < 1.0 # Converged within 1 W/m²
    end
    
    # Apply transient heating correction for short exposures
    if duration < 300 # Less than 5 minutes
      transient_factor = 1 - Math.exp(-duration / calculate_thermal_time_constant)
      temp_rise = temp_surface - ambient_temp
      temp_surface = ambient_temp + (temp_rise * transient_factor)
    end
    
    temp_surface
  end
  
  # Calculate time to reach critical temperature
  def calculate_time_to_critical_temperature
    return Float::INFINITY if incident_heat_flux < 1000 # Negligible heating
    
    ambient_temp = thermal_radiation_incident.ambient_temperature || 288.15
    temp_rise_needed = critical_temperature - ambient_temp
    
    # Simplified transient heating model
    # ΔT = (q" / h_eff) * (1 - exp(-t/τ))
    # where h_eff is effective heat transfer coefficient and τ is time constant
    
    h_eff = calculate_effective_heat_transfer_coefficient
    tau = calculate_thermal_time_constant
    
    if h_eff > 0 && incident_heat_flux / h_eff > temp_rise_needed
      # Will reach critical temperature
      time_to_critical = -tau * Math.log(1 - (temp_rise_needed * h_eff) / incident_heat_flux)
      [time_to_critical, 0.0].max
    else
      # Will not reach critical temperature
      Float::INFINITY
    end
  end
  
  # Calculate thermal stress effects
  def calculate_thermal_stress_effects!
    temp_rise = surface_temperature - (thermal_radiation_incident.ambient_temperature || 288.15)
    
    # Thermal expansion stress (simplified)
    # σ = E * α * ΔT where E is modulus, α is expansion coefficient
    
    expansion_coefficients = {
      'steel' => 12e-6, # /K
      'aluminum' => 23e-6,
      'concrete' => 10e-6,
      'plastic' => 70e-6,
      'wood' => 5e-6
    }
    
    alpha = expansion_coefficients[material_type] || 12e-6
    
    # Approximate elastic modulus (Pa)
    elastic_moduli = {
      'steel' => 200e9,
      'aluminum' => 70e9,
      'concrete' => 30e9,
      'plastic' => 3e9,
      'wood' => 12e9
    }
    
    modulus = elastic_moduli[material_type] || 200e9
    
    # Calculate thermal stress
    thermal_stress = modulus * alpha * temp_rise
    
    # Material yield strength (Pa)
    yield_strengths = {
      'steel' => 250e6,
      'aluminum' => 120e6,
      'concrete' => 30e6,
      'plastic' => 50e6,
      'wood' => 40e6
    }
    
    yield_strength = yield_strengths[material_type] || 250e6
    
    # Check for thermal stress failure
    stress_ratio = thermal_stress / yield_strength
    
    {
      thermal_stress: thermal_stress,
      yield_strength: yield_strength,
      stress_ratio: stress_ratio,
      thermal_stress_failure: stress_ratio > 1.0
    }
  end
  
  # Assess damage state and failure probability
  def assess_damage_and_failure!
    # Get equipment vulnerability factors
    vuln_factors = EQUIPMENT_VULNERABILITY[equipment_type] || EQUIPMENT_VULNERABILITY['structure']
    
    # Base damage assessment from heat flux
    base_damage_prob = calculate_base_damage_probability
    
    # Apply vulnerability factors
    adjusted_prob = base_damage_prob * vuln_factors[:base_vulnerability]
    
    # Material-specific adjustments
    material_factor = calculate_material_vulnerability_factor
    adjusted_prob *= material_factor
    
    # Temperature-based adjustments
    if surface_temperature >= critical_temperature
      adjusted_prob *= 3.0 # Significant increase if critical temp exceeded
    end
    
    # Pressure effects (for pressure equipment)
    if equipment_type.in?(['storage_tank', 'pressure_vessel'])
      adjusted_prob *= vuln_factors[:pressure_factor]
    end
    
    # Contents effects (if contains flammables)
    if contents_ignition_potential?
      adjusted_prob *= vuln_factors[:contents_factor]
    end
    
    # Cap probability at 0.99
    self.failure_probability = [adjusted_prob, 0.99].min
    
    # Determine damage state
    self.damage_state = determine_damage_state(failure_probability)
    
    # Structural failure assessment
    self.structural_failure = assess_structural_failure
    
    # Contents ignition assessment
    self.contents_ignition = assess_contents_ignition
  end
  
  # Calculate economic impacts
  def calculate_economic_impacts!
    # Equipment replacement cost
    self.replacement_cost = calculate_replacement_cost
    
    # Contents value
    self.contents_value = calculate_contents_value
    
    # Business interruption
    self.business_interruption_cost = calculate_business_interruption_cost
    
    # Total economic impact
    total_impact = (replacement_cost || 0) + (contents_value || 0) + (business_interruption_cost || 0)
    
    # Apply damage probability
    expected_loss = total_impact * (failure_probability || 0)
    
    expected_loss
  end
  
  # Assess secondary hazards and escalation potential
  def assess_secondary_hazards!
    hazards = []
    
    # Fire/explosion hazards
    if contents_ignition
      hazards << 'secondary_fire'
      if equipment_type.in?(['storage_tank', 'pressure_vessel'])
        hazards << 'bleve_potential'
      end
    end
    
    # Toxic release hazards
    if structural_failure && equipment_type.in?(['storage_tank', 'pressure_vessel', 'piping'])
      hazards << 'toxic_release'
    end
    
    # Domino effects
    if failure_probability > 0.3
      hazards << 'domino_effect_potential'
      self.escalation_potential = true
    else
      self.escalation_potential = false
    end
    
    # Structural collapse
    if equipment_type == 'structure' && damage_state.in?(['severe', 'failure'])
      hazards << 'structural_collapse'
    end
    
    # Environmental contamination
    if structural_failure && equipment_type.in?(['storage_tank', 'piping'])
      hazards << 'environmental_contamination'
    end
    
    hazards
  end
  
  # Determine required protective measures
  def determine_protective_measures!
    measures = []
    
    # Fire protection
    if incident_heat_flux >= 25000 # 25 kW/m²
      measures << 'active_fire_protection'
      self.fire_protection_required = true
    end
    
    # Cooling systems
    if surface_temperature >= critical_temperature * 0.8
      measures << 'water_cooling_system'
      self.cooling_required = true
    end
    
    # Emergency isolation
    if failure_probability > 0.5 || structural_failure
      measures << 'emergency_isolation'
      self.emergency_isolation_required = true
    end
    
    # Structural reinforcement
    if equipment_type == 'structure' && damage_state.in?(['moderate', 'severe'])
      measures << 'structural_reinforcement'
    end
    
    # Monitoring systems
    if failure_probability > 0.2
      measures << 'continuous_monitoring'
    end
    
    # Evacuation zones
    if escalation_potential
      measures << 'evacuation_zone_establishment'
    end
    
    self.protective_measures = measures.to_json
  end
  
  # Generate detailed thermal damage report
  def generate_thermal_damage_report
    {
      equipment_info: {
        type: equipment_type,
        material: material_type,
        dimensions: {
          height: equipment_height,
          diameter: equipment_diameter,
          surface_area: surface_area
        },
        location: building ? [building.latitude, building.longitude] : nil
      },
      thermal_exposure: {
        incident_heat_flux: incident_heat_flux,
        exposure_duration: exposure_duration,
        surface_temperature: surface_temperature,
        critical_temperature: critical_temperature,
        temperature_exceeded: surface_temperature >= critical_temperature
      },
      damage_assessment: {
        damage_state: damage_state,
        failure_probability: failure_probability,
        time_to_failure: time_to_failure,
        structural_failure: structural_failure,
        contents_ignition: contents_ignition
      },
      thermal_stress: calculate_thermal_stress_effects!,
      economic_impact: {
        replacement_cost: replacement_cost,
        contents_value: contents_value,
        business_interruption: business_interruption_cost,
        total_impact: calculate_economic_impacts!
      },
      hazards: {
        escalation_potential: escalation_potential,
        secondary_hazards: assess_secondary_hazards!
      },
      protective_measures: parse_protective_measures
    }
  end
  
  # Export for GIS visualization
  def to_geojson
    return nil unless building
    
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [building.longitude, building.latitude]
      },
      properties: {
        equipment_type: equipment_type,
        material_type: material_type,
        damage_state: damage_state,
        failure_probability: failure_probability,
        incident_heat_flux: incident_heat_flux,
        surface_temperature: surface_temperature,
        structural_failure: structural_failure,
        escalation_potential: escalation_potential,
        replacement_cost: replacement_cost
      }
    }
  end
  
  # Calculate thermal protection effectiveness
  def calculate_protection_effectiveness(protection_type)
    # Assess effectiveness of different protection methods
    
    effectiveness = case protection_type
                   when 'water_spray'
                     calculate_water_spray_effectiveness
                   when 'insulation'
                     calculate_insulation_effectiveness
                   when 'fireproof_coating'
                     calculate_fireproof_coating_effectiveness
                   when 'heat_shield'
                     calculate_heat_shield_effectiveness
                   else
                     0.0
                   end
    
    {
      protection_type: protection_type,
      effectiveness: effectiveness,
      protected_heat_flux: incident_heat_flux * (1 - effectiveness),
      recommended: effectiveness > 0.5
    }
  end
  
  private
  
  # Calculate base damage probability from heat flux
  def calculate_base_damage_probability
    # Empirical correlation based on heat flux level
    flux_kw = incident_heat_flux / 1000.0 # Convert to kW/m²
    
    case flux_kw
    when 0...5
      0.01
    when 5...15
      0.05 + (flux_kw - 5) * 0.01
    when 15...30
      0.15 + (flux_kw - 15) * 0.02
    when 30...50
      0.45 + (flux_kw - 30) * 0.015
    when 50...100
      0.75 + (flux_kw - 50) * 0.004
    else
      0.95
    end
  end
  
  # Calculate material-specific vulnerability factor
  def calculate_material_vulnerability_factor
    case material_type
    when 'steel'
      1.0 # Baseline
    when 'aluminum'
      1.3 # More vulnerable to heat
    when 'concrete'
      0.8 # More resistant
    when 'plastic', 'wood'
      2.0 # Very vulnerable
    when 'fiberglass'
      1.5 # Moderately vulnerable
    else
      1.0
    end
  end
  
  # Determine damage state from failure probability
  def determine_damage_state(prob)
    case prob
    when 0...0.1
      'none'
    when 0.1...0.3
      'minor'
    when 0.3...0.6
      'moderate'
    when 0.6...0.9
      'severe'
    else
      'failure'
    end
  end
  
  # Assess if structural failure occurs
  def assess_structural_failure
    return false if damage_state == 'none'
    
    # Structural failure more likely for certain equipment types
    structural_equipment = ['storage_tank', 'pressure_vessel', 'structure']
    
    if equipment_type.in?(structural_equipment)
      # Higher chance of structural failure
      failure_probability > 0.7 || 
      surface_temperature >= critical_temperature ||
      damage_state == 'failure'
    else
      # Lower chance for other equipment
      failure_probability > 0.9 || damage_state == 'failure'
    end
  end
  
  # Assess if contents ignition occurs
  def assess_contents_ignition
    return false unless contents_ignition_potential?
    
    # Contents ignition depends on surface temperature and equipment type
    ignition_temp = case equipment_type
                   when 'storage_tank'
                     533.15 # 260°C for hydrocarbon ignition
                   when 'pressure_vessel'
                     523.15 # 250°C
                   when 'vehicle'
                     553.15 # 280°C for fuel
                   else
                     573.15 # 300°C default
                   end
    
    surface_temperature >= ignition_temp || 
    incident_heat_flux >= 37500 # 37.5 kW/m² auto-ignition threshold
  end
  
  # Check if equipment potentially contains ignitable contents
  def contents_ignition_potential?
    case equipment_type
    when 'storage_tank', 'pressure_vessel'
      true # Assume contains flammables
    when 'vehicle'
      true # Contains fuel
    when 'piping'
      true # May contain flammables
    else
      false
    end
  end
  
  # Heat transfer calculations
  def calculate_convective_coefficient
    # Natural convection coefficient (W/m²/K)
    # Depends on surface orientation and temperature difference
    
    temp_diff = [surface_temperature - (thermal_radiation_incident.ambient_temperature || 288.15), 1.0].max
    
    # Simplified correlation for vertical surfaces
    h_conv = 1.42 * (temp_diff ** 0.25)
    
    # Wind effects
    if thermal_radiation_incident.wind_speed.present? && thermal_radiation_incident.wind_speed > 2.0
      wind_speed = thermal_radiation_incident.wind_speed
      h_forced = 5.7 + 3.8 * wind_speed # Forced convection
      h_conv = [h_conv, h_forced].max
    end
    
    h_conv
  end
  
  def calculate_conduction_heat_flux(surface_temp, ambient_temp)
    # Simplified 1D conduction through wall
    thickness = wall_thickness || 0.01 # Default 1 cm thickness
    k = thermal_conductivity || 50.0
    
    (k / thickness) * (surface_temp - ambient_temp)
  end
  
  def calculate_effective_heat_transfer_coefficient
    h_conv = calculate_convective_coefficient
    h_rad = emissivity * 5.67e-8 * 4 * ((surface_temperature + (thermal_radiation_incident.ambient_temperature || 288.15)) / 2)**3
    
    h_conv + h_rad
  end
  
  def calculate_thermal_time_constant
    # Thermal time constant for transient heating
    thickness = wall_thickness || 0.01
    rho = density || 7850.0
    cp = specific_heat || 500.0
    h_eff = calculate_effective_heat_transfer_coefficient
    
    (rho * cp * thickness) / h_eff
  end
  
  # Economic calculations
  def calculate_replacement_cost
    # Equipment replacement cost estimation
    
    base_costs = {
      'storage_tank' => 50000, # USD per tank
      'pressure_vessel' => 100000,
      'piping' => 1000, # USD per meter
      'structure' => 500, # USD per m²
      'vehicle' => 30000,
      'electrical_equipment' => 20000,
      'process_equipment' => 80000
    }
    
    base_cost = base_costs[equipment_type] || 25000
    
    # Size adjustments
    if equipment_type.in?(['storage_tank', 'pressure_vessel'])
      volume = Math::PI * (equipment_diameter || 10)**2 * (equipment_height || 10) / 4
      size_factor = (volume / 100.0)**0.6 # Economy of scale
      base_cost *= size_factor
    elsif equipment_type == 'structure'
      area = surface_area || (building&.area) || 1000
      base_cost *= (area / 1000.0)
    end
    
    # Material cost factor
    material_factors = {
      'steel' => 1.0,
      'aluminum' => 1.5,
      'concrete' => 0.8,
      'plastic' => 0.6,
      'stainless_steel' => 2.0
    }
    
    base_cost * (material_factors[material_type] || 1.0)
  end
  
  def calculate_contents_value
    return 0 unless contents_ignition_potential?
    
    # Contents value estimation
    case equipment_type
    when 'storage_tank'
      volume = Math::PI * (equipment_diameter || 10)**2 * (equipment_height || 10) / 4
      value_per_m3 = 800 # USD per m³ for hydrocarbons
      volume * value_per_m3
    when 'pressure_vessel'
      50000 # USD typical process contents
    when 'vehicle'
      5000 # USD fuel and vehicle value portion
    else
      10000 # USD default
    end
  end
  
  def calculate_business_interruption_cost
    # Business interruption from equipment failure
    
    daily_revenue_factors = {
      'storage_tank' => 10000, # USD per day
      'pressure_vessel' => 50000,
      'piping' => 5000,
      'structure' => 2000,
      'electrical_equipment' => 15000,
      'process_equipment' => 30000
    }
    
    daily_revenue = daily_revenue_factors[equipment_type] || 5000
    
    interruption_days = case damage_state
                       when 'none' then 0
                       when 'minor' then 1
                       when 'moderate' then 7
                       when 'severe' then 30
                       when 'failure' then 90
                       else 14
                       end
    
    daily_revenue * interruption_days
  end
  
  # Protection effectiveness calculations
  def calculate_water_spray_effectiveness
    # Water spray cooling effectiveness
    if incident_heat_flux > 100000 # Very high heat flux
      0.7 # 70% reduction
    elsif incident_heat_flux > 50000
      0.8 # 80% reduction
    else
      0.9 # 90% reduction
    end
  end
  
  def calculate_insulation_effectiveness
    # Thermal insulation effectiveness
    insulation_factor = case material_type
                       when 'steel', 'aluminum'
                         0.6 # Good effectiveness on metals
                       when 'concrete'
                         0.3 # Some effectiveness
                       else
                         0.4 # Moderate effectiveness
                       end
    
    insulation_factor
  end
  
  def calculate_fireproof_coating_effectiveness
    # Fireproof coating effectiveness
    case material_type
    when 'steel'
      0.7 # Very effective on steel
    when 'aluminum'
      0.6 # Good effectiveness
    when 'concrete'
      0.2 # Limited additional benefit
    else
      0.4 # Moderate effectiveness
    end
  end
  
  def calculate_heat_shield_effectiveness
    # Heat shield effectiveness
    if incident_heat_flux > 75000 # Very high heat flux
      0.5 # Limited effectiveness at extreme levels
    else
      0.8 # Good effectiveness at moderate levels
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
end