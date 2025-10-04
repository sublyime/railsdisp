# Chemical model with comprehensive physical and chemical properties
# Based on ALOHA Technical Documentation Chapter 2 - Integral Databases

class Chemical < ApplicationRecord
  has_many :toxicological_data, dependent: :destroy
  has_many :chemical_solutions, dependent: :destroy
  has_many :dispersion_events, dependent: :destroy
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :cas_number, presence: true, uniqueness: { case_sensitive: false }
  validates :molecular_weight, presence: true, numericality: { greater_than: 0 }
  validates :state, presence: true, inclusion: { in: %w[gas liquid solid] }
  validates :hazard_class, presence: true
  
  # Serialize JSON fields
  serialize :synonyms, type: Array, coder: JSON
  serialize :vapor_pressure_coeffs, type: Array, coder: JSON
  serialize :liquid_density_coeffs, type: Array, coder: JSON
  serialize :gas_density_coeffs, type: Array, coder: JSON
  serialize :heat_of_vaporization_coeffs, type: Array, coder: JSON
  serialize :liquid_heat_capacity_coeffs, type: Array, coder: JSON
  serialize :vapor_heat_capacity_coeffs, type: Array, coder: JSON
  serialize :safety_warnings, type: Array, coder: JSON
  
  scope :by_state, ->(state) { where(state: state) }
  scope :by_hazard_class, ->(hazard_class) { where(hazard_class: hazard_class) }
  scope :flammable, -> { where.not(lower_flammability_limit: nil) }
  scope :toxic, -> { joins(:toxicological_data) }
  scope :reactive, -> { where(reactive_with_air: true).or(where(reactive_with_water: true)) }
  
  def display_name
    "#{name} (#{cas_number})"
  end
  
  # Physical property calculations based on ALOHA methodology
  
  # Calculate vapor pressure using Antoine equation: log10(P) = A - B/(C + T)
  # Returns pressure in Pa for temperature in K
  def vapor_pressure(temperature_k)
    return nil unless vapor_pressure_coeffs&.length == 3
    
    a, b, c = vapor_pressure_coeffs
    log_p = a - (b / (c + temperature_k))
    pressure_mmhg = 10 ** log_p
    pressure_mmhg * 133.322 # Convert mmHg to Pa
  end
  
  # Calculate liquid density in kg/m³ for temperature in K
  def liquid_density(temperature_k)
    return nil unless liquid_density_coeffs&.length >= 2
    
    c1, c2, c3, c4 = liquid_density_coeffs.values_at(0, 1, 2, 3)
    c3 ||= 0
    c4 ||= 0
    
    c1 + c2 * temperature_k + c3 * (temperature_k ** 2) + c4 * (temperature_k ** 3)
  end
  
  # Calculate gas density using ideal gas law with corrections
  def gas_density(temperature_k, pressure_pa)
    # ρ = (P * MW) / (R * T)
    # R = 8.314 J/(mol·K)
    (pressure_pa * molecular_weight) / (8.314 * temperature_k)
  end
  
  # Calculate heat of vaporization in J/kg for temperature in K
  def heat_of_vaporization(temperature_k)
    return nil unless heat_of_vaporization_coeffs&.length >= 2
    
    c1, c2, c3, c4 = heat_of_vaporization_coeffs.values_at(0, 1, 2, 3)
    c3 ||= 0
    c4 ||= 0
    
    c1 + c2 * temperature_k + c3 * (temperature_k ** 2) + c4 * (temperature_k ** 3)
  end
  
  # Calculate liquid heat capacity in J/(kg·K) for temperature in K
  def liquid_heat_capacity(temperature_k)
    return nil unless liquid_heat_capacity_coeffs&.length >= 2
    
    c1, c2, c3, c4 = liquid_heat_capacity_coeffs.values_at(0, 1, 2, 3)
    c3 ||= 0
    c4 ||= 0
    
    c1 + c2 * temperature_k + c3 * (temperature_k ** 2) + c4 * (temperature_k ** 3)
  end
  
  # Calculate vapor heat capacity in J/(kg·K) for temperature in K
  def vapor_heat_capacity(temperature_k)
    return nil unless vapor_heat_capacity_coeffs&.length >= 2
    
    c1, c2, c3, c4 = vapor_heat_capacity_coeffs.values_at(0, 1, 2, 3)
    c3 ||= 0
    c4 ||= 0
    
    c1 + c2 * temperature_k + c3 * (temperature_k ** 2) + c4 * (temperature_k ** 3)
  end
  
  # Calculate molecular diffusivity using Graham's Law if not available
  # Returns diffusivity in m²/s
  def molecular_diffusivity_in_air
    if molecular_diffusivity.present?
      molecular_diffusivity
    else
      # Graham's Law: κc = κw * sqrt(Mw/Mc)
      # where κw = 2.39 × 10⁻⁵ m²/s for water vapor
      water_molecular_weight = 18.015
      water_diffusivity = 2.39e-5
      
      water_diffusivity * Math.sqrt(water_molecular_weight / molecular_weight)
    end
  end
  
  # Determine if chemical is a dense gas (heavier than air)
  def dense_gas?(temperature_k = 288.15, pressure_pa = 101325)
    air_density = 1.225 # kg/m³ at standard conditions
    chemical_density = gas_density(temperature_k, pressure_pa)
    
    chemical_density > air_density if chemical_density
  end
  
  # Calculate reduced gravity for heavy gas dispersion
  def reduced_gravity(temperature_k = 288.15, pressure_pa = 101325)
    air_density = 1.225 # kg/m³ at standard conditions
    chemical_density = gas_density(temperature_k, pressure_pa)
    
    return 0 unless chemical_density
    
    9.8 * (chemical_density - air_density) / air_density
  end
  
  # Determine appropriate dispersion model based on density
  def recommended_dispersion_model(temperature_k = 288.15, pressure_pa = 101325)
    return dispersion_model_preference if dispersion_model_preference.present?
    
    dense_gas?(temperature_k, pressure_pa) ? 'heavy_gas' : 'gaussian'
  end
  
  # Reactivity warnings for user interface
  def reactivity_warnings
    warnings = []
    warnings << "Reacts with air - may form explosive mixtures" if reactive_with_air?
    warnings << "Reacts with water - may generate heat or toxic gases" if reactive_with_water?
    warnings << "Highly water soluble - ground contamination risk" if water_soluble? && water_solubility.to_f > 50
    warnings.concat(safety_warnings) if safety_warnings.present?
    warnings
  end
  
  # Check if chemical is within flammability limits at given concentration
  def within_flammability_limits?(concentration_ppm)
    return false unless flammable?
    
    concentration_ppm >= lower_flammability_limit * 10000 && 
    concentration_ppm <= upper_flammability_limit * 10000
  end
  
  def flammable?
    lower_flammability_limit.present? && upper_flammability_limit.present?
  end
  
  # Get primary toxicological guideline for emergency response
  def primary_emergency_guideline(duration_minutes = 60)
    tox_data = toxicological_data.first
    return nil unless tox_data
    
    # Prefer AEGLs, then ERPGs, then PACs, then IDLH
    case duration_minutes
    when 0..15
      tox_data.aegl_3_10min || tox_data.pac_3_10min
    when 16..45
      tox_data.aegl_3_30min || tox_data.pac_3_30min
    when 46..90
      tox_data.aegl_3_1hr || tox_data.erpg_3 || tox_data.pac_3_1hr || tox_data.idlh
    when 91..300
      tox_data.aegl_3_4hr || tox_data.pac_3_4hr
    else
      tox_data.aegl_3_8hr || tox_data.pac_3_8hr
    end
  end
  
  # Convert concentration units (ppm to mg/m³ and vice versa)
  def ppm_to_mg_m3(ppm, temperature_k = 288.15, pressure_pa = 101325)
    # ppm * (MW * P) / (R * T) where MW in g/mol
    ppm * (molecular_weight * pressure_pa) / (8.314 * temperature_k)
  end
  
  def mg_m3_to_ppm(mg_m3, temperature_k = 288.15, pressure_pa = 101325)
    # mg/m³ * (R * T) / (MW * P) where MW in g/mol
    mg_m3 * (8.314 * temperature_k) / (molecular_weight * pressure_pa)
  end
  
  # Calculate dispersion coefficients based on chemical properties
  def dispersion_coefficient
    # Simplified calculation - in reality this would be much more complex
    case state
    when 'gas'
      vapor_pressure.to_f / molecular_weight.to_f
    when 'liquid'
      density.to_f * vapor_pressure.to_f
    else
      0.1 # Default for solids
    end
  end
end
