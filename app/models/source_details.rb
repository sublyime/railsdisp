# SourceDetails model - Contains source-specific parameters and calculations
# Implements ALOHA source strength models for all four source types

class SourceDetails < ApplicationRecord
  belongs_to :dispersion_scenario
  
  validates :dispersion_scenario_id, presence: true, uniqueness: true
  
  # Validation based on source type
  validate :validate_source_parameters
  
  # Constants for calculations
  DISCHARGE_COEFFICIENT = 0.61 # For tank releases
  ENTRAINMENT_COEFFICIENT = 0.85 # For heavy gas calculations
  GAMMA_FUNCTION_VALUES = { # Γ(1/(1+n)) for different n values
    0.108 => 0.945, 0.112 => 0.943, 0.120 => 0.940,
    0.142 => 0.932, 0.203 => 0.901, 0.253 => 0.871
  }.freeze
  
  # PUDDLE SOURCE CALCULATIONS (ALOHA Section 3.3)
  
  def calculate_puddle_evaporation(scenario, time_step)
    return unless scenario.source_type == 'puddle'
    
    temp_k = puddle_temperature || scenario.ambient_temperature
    area = puddle_area || (Math::PI * (puddle_diameter / 2) ** 2)
    
    # Determine if puddle is boiling
    boiling = boiling_puddle? || puddle_is_boiling?(scenario, temp_k)
    
    if boiling
      evap_rate = calculate_boiling_evaporation(scenario, temp_k, area)
    else
      evap_rate = calculate_brighton_evaporation(scenario, temp_k, area)
    end
    
    # Energy balance to update puddle temperature
    new_temp = calculate_puddle_energy_balance(scenario, temp_k, area, evap_rate, time_step)
    
    scenario.release_calculations.create!(
      time_step: time_step,
      mass_flow_rate: evap_rate * area, # kg/s
      evaporation_rate: evap_rate, # kg/(m²·s)
      temperature: new_temp,
      pressure: scenario.atmospheric_pressure,
      density: scenario.chemical.gas_density(new_temp, scenario.atmospheric_pressure),
      puddle_radius: Math.sqrt(area / Math::PI),
      puddle_mass: calculate_puddle_mass(area)
    )
  end
  
  # Brighton's evaporation model for non-boiling puddles (ALOHA 3.3.1)
  def calculate_brighton_evaporation(scenario, temperature_k, area)
    chemical = scenario.chemical
    
    # Vapor pressure and concentration
    vapor_pressure = chemical.vapor_pressure(temperature_k) || 1000
    molecular_weight = chemical.molecular_weight
    
    # Saturation concentration (kg/m³)
    cs = (vapor_pressure * molecular_weight) / (8.314 * temperature_k)
    
    # Friction velocity
    u_star = scenario.friction_velocity
    
    # Mass transfer coefficient calculation
    j_c = calculate_mass_transfer_coefficient(scenario, area, chemical)
    
    # Brighton's formula: E = Cs * U* * jc
    cs * u_star * j_c
  end
  
  # Calculate mass transfer coefficient for Brighton model
  def calculate_mass_transfer_coefficient(scenario, area, chemical)
    # Simplified calculation - full ALOHA implementation is quite complex
    
    # Schmidt number
    diffusivity = chemical.molecular_diffusivity_in_air
    kinematic_viscosity = 1.5e-5 # m²/s for air at standard conditions
    schmidt = kinematic_viscosity / diffusivity
    
    # Roughness Reynolds number
    u_star = scenario.friction_velocity
    z0 = scenario.surface_roughness_length
    re0 = (u_star * z0) / kinematic_viscosity
    
    # Dimensionless parameters
    n = DispersionScenario::PASQUILL_PARAMETERS[scenario.stability_class][:n]
    diameter = Math.sqrt(4 * area / Math::PI)
    
    # Simplified mass transfer coefficient
    # Full calculation involves complex integration and stability functions
    base_coeff = 0.037 * (schmidt ** -0.67)
    
    # Apply volatility correction for high vapor pressure
    vapor_pressure = chemical.vapor_pressure(puddle_temperature || scenario.ambient_temperature) || 1000
    atm_pressure = scenario.atmospheric_pressure
    
    if vapor_pressure / atm_pressure > 0.1
      volatility_correction = Math.log(1 - vapor_pressure / atm_pressure) / (-vapor_pressure / atm_pressure)
      base_coeff *= volatility_correction
    end
    
    base_coeff
  end
  
  # Boiling puddle evaporation rate based on energy balance (ALOHA 3.3.2)
  def calculate_boiling_evaporation(scenario, temperature_k, area)
    # For boiling puddles, evaporation rate is determined by heat balance
    chemical = scenario.chemical
    
    # Heat of vaporization
    heat_vap = chemical.heat_of_vaporization(temperature_k) || 400000 # J/kg
    
    # Net heat flux into puddle
    net_heat_flux = calculate_net_heat_flux(scenario, temperature_k, area)
    
    # Evaporation rate = Net heat flux / Heat of vaporization
    [net_heat_flux / heat_vap, 0].max # Ensure non-negative
  end
  
  # Check if puddle temperature reaches boiling point
  def puddle_is_boiling?(scenario, temperature_k)
    boiling_point = scenario.chemical.normal_boiling_point
    return false unless boiling_point
    
    # Adjust boiling point for pressure
    pressure_correction = Math.log(scenario.atmospheric_pressure / 101325) * 20 # Simplified
    adjusted_bp = boiling_point + pressure_correction
    
    temperature_k >= adjusted_bp - 5 # 5K tolerance
  end
  
  # Calculate net heat flux into puddle (ALOHA 3.3.3)
  def calculate_net_heat_flux(scenario, temperature_k, area)
    # Solar radiation
    solar_flux = scenario.solar_radiation_flux
    
    # Longwave radiation exchange
    air_temp = scenario.ambient_temperature
    emissivity = 0.97 # For most liquids
    sigma = DispersionScenario::STEFAN_BOLTZMANN
    
    # Downward longwave from atmosphere
    cloud_factor = 0.87 + 0.026 * scenario.cloud_cover
    longwave_down = cloud_factor * sigma * (air_temp ** 4)
    
    # Upward longwave from puddle
    longwave_up = emissivity * sigma * (temperature_k ** 4)
    
    # Ground heat conduction
    ground_flux = calculate_ground_heat_flux(temperature_k)
    
    # Sensible heat from air
    sensible_flux = calculate_sensible_heat_flux(scenario, temperature_k)
    
    # Net flux (W/m²)
    solar_flux + longwave_down - longwave_up + ground_flux + sensible_flux
  end
  
  # Ground heat conduction (ALOHA 3.3.3.2)
  def calculate_ground_heat_flux(puddle_temp)
    ground_temp = surface_temperature || 288.15
    temp_diff = ground_temp - puddle_temp
    
    # Thermal conductivity based on surface type
    thermal_conductivity = case surface_type
    when 'concrete' then 8.28 # W/(m·K) with correction factor
    when 'soil' then 2.34
    when 'water' then 500 * temp_diff # Simplified convective model
    else 2.34
    end
    
    # Simplified steady-state conduction
    temp_diff * thermal_conductivity / 0.1 # Assuming 10cm depth
  end
  
  # Sensible heat flux from air (ALOHA 3.3.3.5)
  def calculate_sensible_heat_flux(scenario, puddle_temp)
    air_temp = scenario.ambient_temperature
    temp_diff = air_temp - puddle_temp
    
    # Air properties
    air_density = 1.225 # kg/m³ at standard conditions
    air_cp = 1004 # J/(kg·K)
    
    # Heat transfer coefficient (simplified)
    u_star = scenario.friction_velocity
    ch = 0.001 # Sensible heat transfer coefficient
    
    air_density * air_cp * u_star * ch * temp_diff
  end
  
  # TANK SOURCE CALCULATIONS (ALOHA Section 3.4)
  
  def calculate_tank_release(scenario, time_step)
    return unless scenario.source_type == 'tank'
    
    # Determine release phase
    phase = determine_release_phase(scenario)
    
    case phase
    when 'gas'
      mass_flow = calculate_gas_release_rate(scenario)
    when 'liquid'
      mass_flow = calculate_liquid_release_rate(scenario)
    when 'two_phase'
      mass_flow = calculate_two_phase_release_rate(scenario)
    else
      mass_flow = 0
    end
    
    # Update tank conditions
    update_tank_conditions(scenario, mass_flow, time_step)
    
    scenario.release_calculations.create!(
      time_step: time_step,
      mass_flow_rate: mass_flow,
      temperature: tank_temperature || scenario.ambient_temperature,
      pressure: tank_pressure || scenario.atmospheric_pressure,
      density: calculate_release_density(scenario, phase),
      tank_internal_pressure: tank_pressure,
      tank_internal_temperature: tank_temperature,
      liquid_remaining: calculate_liquid_remaining
    )
  end
  
  # Determine phase of material being released
  def determine_release_phase(scenario)
    # Simplified phase determination
    vapor_pressure = scenario.chemical.vapor_pressure(tank_temperature || scenario.ambient_temperature)
    
    if hole_height && liquid_level && hole_height > liquid_level
      'gas' # Hole above liquid level
    elsif tank_pressure && vapor_pressure && tank_pressure > vapor_pressure * 1.5
      'two_phase' # Superheated liquid
    else
      'liquid' # Normal liquid release
    end
  end
  
  # Gas release through hole (ALOHA 3.4.6)
  def calculate_gas_release_rate(scenario)
    return 0 unless hole_area && tank_pressure
    
    gamma = scenario.chemical.gamma_ratio || 1.4
    pressure_ratio = scenario.atmospheric_pressure / tank_pressure
    
    # Critical pressure ratio for sonic flow
    critical_ratio = (2 / (gamma + 1)) ** (gamma / (gamma - 1))
    
    if pressure_ratio <= critical_ratio
      # Choked flow
      mass_flow = DISCHARGE_COEFFICIENT * hole_area * tank_pressure * 
                  Math.sqrt(gamma / (8.314 * tank_temperature) * 
                  scenario.chemical.molecular_weight) *
                  ((gamma + 1) / 2) ** ((gamma + 1) / (2 * (gamma - 1)))
    else
      # Unchoked flow
      mass_flow = DISCHARGE_COEFFICIENT * hole_area * tank_pressure *
                  Math.sqrt(2 * gamma / ((gamma - 1) * 8.314 * tank_temperature) *
                  scenario.chemical.molecular_weight) *
                  Math.sqrt((pressure_ratio ** (2/gamma)) - (pressure_ratio ** ((gamma+1)/gamma)))
    end
    
    [mass_flow, 0].max
  end
  
  # Liquid release using Bernoulli equation (ALOHA 3.4.4)
  def calculate_liquid_release_rate(scenario)
    return 0 unless hole_area && liquid_level && tank_pressure
    
    # Pressure at hole
    hydrostatic_pressure = 0
    if hole_height && hole_height < liquid_level
      liquid_density = scenario.chemical.liquid_density(tank_temperature || scenario.ambient_temperature) || 1000
      hydrostatic_pressure = liquid_density * 9.8 * (liquid_level - hole_height)
    end
    
    pressure_diff = tank_pressure + hydrostatic_pressure - scenario.atmospheric_pressure
    pressure_diff = [pressure_diff, 1.01].max # Minimum pressure difference
    
    # Bernoulli equation
    velocity = Math.sqrt(2 * pressure_diff / (liquid_density || 1000))
    mass_flow = DISCHARGE_COEFFICIENT * hole_area * (liquid_density || 1000) * velocity
    
    [mass_flow, 0].max
  end
  
  # Two-phase release using Homogeneous Nonequilibrium Model (ALOHA 3.4.5)
  def calculate_two_phase_release_rate(scenario)
    return 0 unless tank_pressure && hole_area
    
    chemical = scenario.chemical
    temp = tank_temperature || scenario.ambient_temperature
    
    # Heat of vaporization and specific volumes
    heat_vap = chemical.heat_of_vaporization(temp) || 400000
    liquid_density = chemical.liquid_density(temp) || 1000
    gas_density = chemical.gas_density(temp, tank_pressure) || 1.0
    
    v_liquid = 1.0 / liquid_density
    v_gas = 1.0 / gas_density
    
    # Heat capacity
    cp = chemical.liquid_heat_capacity(temp) || 4000
    
    # Nonequilibrium parameter
    pipe_len = (pipe_length_type == 'short_pipe') ? (pipe_length || 0.1) : 0
    equivalent_length = pipe_len + 0.1 # Add entrance effects
    
    nc = (heat_vap / (cp * temp)) * Math.sqrt(equivalent_length / (DISCHARGE_COEFFICIENT * (v_gas - v_liquid)))
    
    # Mass flux calculation (simplified)
    pressure_diff = tank_pressure - scenario.atmospheric_pressure
    g_value = Math.sqrt(2 * pressure_diff / (1 + nc))
    
    mass_flow = hole_area * g_value
    
    [mass_flow, 0].max
  end
  
  # GAS PIPELINE CALCULATIONS (ALOHA Section 3.5)
  
  def calculate_pipeline_release(scenario, time_step)
    return unless scenario.source_type == 'pipeline'
    
    # Wilson's double exponential model for pipeline release
    initial_flow = calculate_initial_pipeline_flow(scenario)
    alpha, beta = calculate_pipeline_parameters(scenario)
    
    time_sec = time_step
    mass_flow = initial_flow * (1 + alpha) * Math.exp(-time_sec / beta) - 
                initial_flow * alpha * Math.exp(-time_sec / (beta * alpha))
    
    scenario.release_calculations.create!(
      time_step: time_step,
      mass_flow_rate: [mass_flow, 0].max,
      temperature: pipeline_temperature || scenario.ambient_temperature,
      pressure: pipeline_pressure || scenario.atmospheric_pressure,
      density: scenario.chemical.gas_density(
        pipeline_temperature || scenario.ambient_temperature,
        pipeline_pressure || scenario.atmospheric_pressure
      )
    )
  end
  
  # Calculate initial choked flow rate for pipeline
  def calculate_initial_pipeline_flow(scenario)
    return 0 unless hole_area && pipeline_pressure
    
    gamma = scenario.chemical.gamma_ratio || 1.4
    molecular_weight = scenario.chemical.molecular_weight
    temp = pipeline_temperature || scenario.ambient_temperature
    
    # Choked flow calculation
    gamma_factor = Math.sqrt(gamma * ((gamma + 1) / 2) ** (-(gamma + 1) / (gamma - 1)))
    
    hole_area * pipeline_pressure * gamma_factor * 
    Math.sqrt(molecular_weight / (8.314 * temp))
  end
  
  # Calculate pipeline release parameters (Wilson model)
  def calculate_pipeline_parameters(scenario)
    return [1.0, 3600.0] unless pipeline_length && pipeline_diameter
    
    # Simplified parameter calculation
    # Full ALOHA implementation involves complex flow calculations
    
    length = pipeline_length
    diameter = pipeline_diameter
    pressure = pipeline_pressure || scenario.atmospheric_pressure
    
    # Time constant (beta)
    sound_speed = Math.sqrt(1.4 * 8.314 * (pipeline_temperature || scenario.ambient_temperature) / 
                          scenario.chemical.molecular_weight)
    
    beta = length / sound_speed
    
    # Mass conservation factor (alpha)
    hole_ratio = Math.sqrt(hole_area) / diameter
    alpha = 1.0 / (1.0 + hole_ratio * 10) # Simplified relationship
    
    [alpha, beta]
  end
  
  private
  
  def validate_source_parameters
    case dispersion_scenario&.source_type
    when 'direct'
      errors.add(:direct_release_rate, "is required for direct sources") unless direct_release_rate
    when 'puddle'
      errors.add(:puddle_area, "is required for puddle sources") unless puddle_area || puddle_diameter
    when 'tank'
      errors.add(:tank_volume, "is required for tank sources") unless tank_volume
      errors.add(:hole_area, "is required for tank sources") unless hole_area || hole_diameter
    when 'pipeline'
      errors.add(:pipeline_diameter, "is required for pipeline sources") unless pipeline_diameter
      errors.add(:pipeline_pressure, "is required for pipeline sources") unless pipeline_pressure
    end
  end
  
  def calculate_puddle_mass(area)
    depth = puddle_depth || 0.005 # Default 5mm
    density = dispersion_scenario.chemical.liquid_density(puddle_temperature || 288.15) || 1000
    area * depth * density
  end
  
  def calculate_liquid_remaining
    # Simplified calculation - would need to track mass balance over time
    tank_volume && liquid_level ? tank_volume * 0.8 : 1000
  end
  
  def calculate_release_density(scenario, phase)
    temp = tank_temperature || scenario.ambient_temperature
    pressure = tank_pressure || scenario.atmospheric_pressure
    
    case phase
    when 'gas'
      scenario.chemical.gas_density(temp, pressure)
    when 'liquid'
      scenario.chemical.liquid_density(temp)
    when 'two_phase'
      # Mixture density based on quality
      vapor_fraction = quality || 0.1
      liquid_density = scenario.chemical.liquid_density(temp) || 1000
      gas_density = scenario.chemical.gas_density(temp, pressure) || 1.0
      
      1.0 / (vapor_fraction / gas_density + (1 - vapor_fraction) / liquid_density)
    else
      1.0
    end
  end
  
  def update_tank_conditions(scenario, mass_flow_rate, time_step)
    # Simplified tank condition updates
    # Full implementation would solve coupled ODEs for pressure, temperature, and level
    
    if tank_pressure && mass_flow_rate > 0
      # Pressure drop due to gas expansion
      volume_flow = mass_flow_rate / (calculate_release_density(scenario, 'gas') || 1.0)
      pressure_drop = volume_flow * 100 # Simplified relationship
      
      self.tank_pressure = [tank_pressure - pressure_drop, scenario.atmospheric_pressure].max
    end
  end
end