# ChemicalSolution model for handling chemical solutions (HCl, NH3, HNO3, HF, Oleum)
# Based on ALOHA Technical Documentation Chapter 2.3 - Physical Properties

class ChemicalSolution < ApplicationRecord
  belongs_to :chemical
  
  validates :chemical_id, presence: true
  validates :solution_type, presence: true, 
            inclusion: { in: %w[hydrochloric_acid ammonia nitric_acid hydrofluoric_acid oleum] }
  validates :min_concentration, :max_concentration, 
            presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :min_temperature, :max_temperature,
            presence: true,
            numericality: { greater_than: 0 }
  
  validate :concentration_range_valid
  validate :temperature_range_valid
  
  serialize :vapor_pressure_data, Array
  
  # Calculate solution density at given temperature and concentration
  # Value = C1 + C2*Temperature + C3*MassFraction + C4*MassFraction²
  def density(temperature_k, mass_fraction)
    return nil unless valid_conditions?(temperature_k, mass_fraction)
    
    density_c1 + 
    density_c2 * temperature_k + 
    density_c3 * mass_fraction + 
    density_c4 * (mass_fraction ** 2)
  end
  
  # Calculate solution heat capacity at given temperature and concentration
  def heat_capacity(temperature_k, mass_fraction)
    return nil unless valid_conditions?(temperature_k, mass_fraction)
    
    heat_capacity_c1 + 
    heat_capacity_c2 * temperature_k + 
    heat_capacity_c3 * mass_fraction + 
    heat_capacity_c4 * (mass_fraction ** 2)
  end
  
  # Calculate heat of vaporization at given temperature and concentration
  def heat_of_vaporization(temperature_k, mass_fraction)
    return nil unless valid_conditions?(temperature_k, mass_fraction)
    
    heat_vaporization_c1 + 
    heat_vaporization_c2 * temperature_k + 
    heat_vaporization_c3 * mass_fraction + 
    heat_vaporization_c4 * (mass_fraction ** 2)
  end
  
  # Get vapor pressure by interpolation from stored data
  # Linear interpolation in log(Pressure) and (1/Temperature)
  def vapor_pressure(temperature_k, mass_fraction)
    return nil unless valid_conditions?(temperature_k, mass_fraction)
    return nil unless vapor_pressure_data.present?
    
    # Find closest data points for interpolation
    relevant_data = vapor_pressure_data.select do |point|
      (point['concentration'] - mass_fraction).abs <= 0.05 # Within 5% concentration
    end
    
    return nil if relevant_data.empty?
    
    # Linear interpolation in log(P) vs 1/T space
    closest_point = relevant_data.min_by { |point| (point['temperature'] - temperature_k).abs }
    
    # For now, return closest point - could implement full 2D interpolation
    closest_point['pressure']
  end
  
  # Calculate partial pressure of volatile component
  def partial_pressure(temperature_k, mass_fraction)
    total_pressure = vapor_pressure(temperature_k, mass_fraction)
    return nil unless total_pressure
    
    # For most solutions, the volatile component dominates vapor pressure
    case solution_type
    when 'hydrochloric_acid'
      # HCl partial pressure calculation
      total_pressure * hcl_activity_coefficient(mass_fraction)
    when 'ammonia'
      # NH3 partial pressure calculation  
      total_pressure * nh3_activity_coefficient(mass_fraction)
    when 'nitric_acid'
      # HNO3 partial pressure calculation
      total_pressure * hno3_activity_coefficient(mass_fraction)
    when 'hydrofluoric_acid'
      # HF partial pressure calculation
      total_pressure * hf_activity_coefficient(mass_fraction)
    when 'oleum'
      # SO3 partial pressure calculation
      total_pressure * so3_activity_coefficient(mass_fraction)
    else
      total_pressure
    end
  end
  
  # Check if temperature and concentration are within valid range
  def valid_conditions?(temperature_k, mass_fraction)
    temperature_k >= min_temperature && 
    temperature_k <= max_temperature &&
    mass_fraction >= min_concentration && 
    mass_fraction <= max_concentration
  end
  
  # Get solution properties at standard conditions
  def standard_properties
    std_temp = 298.15 # 25°C
    std_conc = (min_concentration + max_concentration) / 2
    
    {
      temperature: std_temp,
      concentration: std_conc,
      density: density(std_temp, std_conc),
      heat_capacity: heat_capacity(std_temp, std_conc),
      heat_of_vaporization: heat_of_vaporization(std_temp, std_conc),
      vapor_pressure: vapor_pressure(std_temp, std_conc)
    }
  end
  
  # Get concentration range description
  def concentration_range_description
    "#{(min_concentration * 100).round(1)}% to #{(max_concentration * 100).round(1)}% by mass"
  end
  
  private
  
  def concentration_range_valid
    return unless min_concentration && max_concentration
    
    if min_concentration >= max_concentration
      errors.add(:max_concentration, "must be greater than minimum concentration")
    end
  end
  
  def temperature_range_valid
    return unless min_temperature && max_temperature
    
    if min_temperature >= max_temperature
      errors.add(:max_temperature, "must be greater than minimum temperature")
    end
  end
  
  # Activity coefficient calculations for different solutions
  # These are simplified - ALOHA uses more complex empirical correlations
  
  def hcl_activity_coefficient(mass_fraction)
    # Simplified activity coefficient for HCl solutions
    # Real implementation would use Pitzer parameters or similar
    1.0 - 0.5 * mass_fraction
  end
  
  def nh3_activity_coefficient(mass_fraction)
    # Simplified activity coefficient for NH3 solutions
    0.9 - 0.3 * mass_fraction
  end
  
  def hno3_activity_coefficient(mass_fraction)
    # Simplified activity coefficient for HNO3 solutions
    1.1 - 0.4 * mass_fraction
  end
  
  def hf_activity_coefficient(mass_fraction)
    # Simplified activity coefficient for HF solutions
    0.95 - 0.2 * mass_fraction
  end
  
  def so3_activity_coefficient(mass_fraction)
    # Simplified activity coefficient for oleum (SO3 in H2SO4)
    1.2 * mass_fraction
  end
end