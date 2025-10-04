# ReleaseCalculation model - Stores time-stepped calculation results
class ReleaseCalculation < ApplicationRecord
  belongs_to :dispersion_scenario
  
  validates :dispersion_scenario_id, presence: true
  validates :time_step, presence: true, numericality: { greater_than: 0 }
  validates :mass_flow_rate, numericality: { greater_than_or_equal_to: 0 }
  
  scope :by_time_order, -> { order(:time_step) }
  scope :significant_release, -> { where('mass_flow_rate > ?', 0.001) }
  
  # Get release rate in different units
  def mass_flow_rate_kg_hr
    mass_flow_rate * 3600 # Convert kg/s to kg/hr
  end
  
  def volumetric_flow_rate_m3_s
    return 0 unless mass_flow_rate && density && density > 0
    mass_flow_rate / density
  end
  
  def volumetric_flow_rate_m3_hr
    volumetric_flow_rate_m3_s * 3600
  end
  
  # Calculate derived properties
  def momentum_flux
    return 0 unless mass_flow_rate && velocity
    mass_flow_rate * velocity
  end
  
  def reynolds_number(characteristic_length = 1.0)
    return 0 unless velocity && density
    
    # Dynamic viscosity for air at standard conditions
    dynamic_viscosity = 1.8e-5 # Pa·s
    
    (density * velocity * characteristic_length) / dynamic_viscosity
  end
  
  def mach_number
    return 0 unless velocity && temperature
    
    gamma = dispersion_scenario.chemical.gamma_ratio || 1.4
    gas_constant = 8.314
    molecular_weight = dispersion_scenario.chemical.molecular_weight
    
    # Speed of sound
    sound_speed = Math.sqrt(gamma * gas_constant * temperature / molecular_weight)
    
    velocity / sound_speed
  end
  
  # Energy-related calculations
  def kinetic_energy_flux
    return 0 unless mass_flow_rate && velocity
    0.5 * mass_flow_rate * velocity ** 2
  end
  
  def enthalpy_flux
    return 0 unless mass_flow_rate && temperature
    
    # Specific heat capacity
    cp = if dispersion_scenario.chemical.vapor_heat_capacity(temperature)
           dispersion_scenario.chemical.vapor_heat_capacity(temperature)
         else
           1000 # Default for air
         end
    
    mass_flow_rate * cp * temperature
  end
  
  # Heat transfer calculations for puddle sources
  def net_heat_flux
    return 0 unless respond_to_all?([:solar_flux, :longwave_down, :longwave_up, 
                                    :ground_heat_flux, :sensible_heat_flux])
    
    (solar_flux || 0) + (longwave_down || 0) - (longwave_up || 0) + 
    (ground_heat_flux || 0) + (sensible_heat_flux || 0)
  end
  
  def evaporative_cooling_rate
    return 0 unless evaporation_rate && evaporative_heat_flux
    evaporative_heat_flux / (evaporation_rate > 0 ? evaporation_rate : 1)
  end
  
  # Puddle growth calculations
  def puddle_area
    return 0 unless puddle_radius
    Math::PI * puddle_radius ** 2
  end
  
  def puddle_volume
    return 0 unless puddle_radius && dispersion_scenario.source_details&.puddle_depth
    
    puddle_area * dispersion_scenario.source_details.puddle_depth
  end
  
  # Dimensionless parameters for dispersion modeling
  def froude_number
    return 0 unless velocity && puddle_radius
    
    velocity / Math.sqrt(9.8 * puddle_radius)
  end
  
  def richardson_number
    return 0 unless temperature && dispersion_scenario.ambient_temperature
    
    temp_diff = temperature - dispersion_scenario.ambient_temperature
    return 0 if temp_diff == 0
    
    g_reduced = 9.8 * temp_diff / dispersion_scenario.ambient_temperature
    velocity_scale = dispersion_scenario.wind_speed || 1.0
    length_scale = puddle_radius || 1.0
    
    g_reduced * length_scale / (velocity_scale ** 2)
  end
  
  # Stability functions for atmospheric dispersion
  def monin_obukhov_length
    # Simplified calculation
    # Full implementation would use surface heat flux and friction velocity
    
    stability_class = dispersion_scenario.stability_class
    z0 = dispersion_scenario.surface_roughness_length
    
    case stability_class
    when 'A' then -50.0 * z0
    when 'B' then -100.0 * z0  
    when 'C' then -200.0 * z0
    when 'D' then Float::INFINITY # Neutral
    when 'E' then 200.0 * z0
    when 'F' then 100.0 * z0
    else Float::INFINITY
    end
  end
  
  # Chemical-specific calculations
  def vapor_pressure_at_temperature
    dispersion_scenario.chemical.vapor_pressure(temperature || dispersion_scenario.ambient_temperature)
  end
  
  def saturation_concentration
    vp = vapor_pressure_at_temperature
    return 0 unless vp && temperature && pressure
    
    mw = dispersion_scenario.chemical.molecular_weight
    (vp * mw) / (8.314 * temperature)
  end
  
  def concentration_ppm_equivalent
    return 0 unless density && temperature && pressure
    
    # Convert mass concentration to volume concentration
    mw = dispersion_scenario.chemical.molecular_weight
    air_molar_volume = 8.314 * temperature / pressure
    
    (density / mw) * air_molar_volume * 1e6 # Convert to ppm
  end
  
  # Time-dependent functions
  def time_from_start_minutes
    time_step / 60.0
  end
  
  def time_from_start_hours
    time_step / 3600.0
  end
  
  # Cumulative calculations (requires ordering by time_step)
  def cumulative_mass_released
    earlier_calcs = dispersion_scenario.release_calculations
                    .where('time_step <= ?', time_step)
                    .order(:time_step)
    
    total = 0
    prev_time = 0
    
    earlier_calcs.each do |calc|
      dt = calc.time_step - prev_time
      total += calc.mass_flow_rate * dt
      prev_time = calc.time_step
    end
    
    total
  end
  
  def release_efficiency
    return 0 unless dispersion_scenario.source_details
    
    case dispersion_scenario.source_type
    when 'tank'
      initial_mass = dispersion_scenario.source_details.calculate_liquid_remaining || 1000
      cumulative_mass_released / initial_mass
    when 'puddle'
      # Evaporation efficiency vs theoretical maximum
      max_rate = dispersion_scenario.source_details.calculate_theoretical_max_evaporation || 1.0
      evaporation_rate / max_rate
    else
      1.0 # Assume 100% efficiency for direct and pipeline sources
    end
  end
  
  # Quality checks and validation
  def realistic_values?
    return false if mass_flow_rate < 0
    return false if temperature && temperature < 100 # Below 100K is unrealistic
    return false if pressure && pressure < 1000 # Below 10 mbar is unrealistic
    return false if density && density < 0
    return false if velocity && velocity > 1000 # Supersonic flow check
    
    true
  end
  
  def has_complete_data?
    mass_flow_rate.present? && temperature.present? && 
    pressure.present? && density.present?
  end
  
  private
  
  def respond_to_all?(methods)
    methods.all? { |method| respond_to?(method) }
  end
end