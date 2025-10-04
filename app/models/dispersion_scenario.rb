# DispersionScenario model - Main container for chemical release scenarios
# Based on ALOHA Technical Documentation Chapter 3 - Source Strength Models

class DispersionScenario < ApplicationRecord
  belongs_to :chemical
  belongs_to :map_layer, optional: true
  has_one :source_details, dependent: :destroy
  has_many :release_calculations, dependent: :destroy
  has_many :atmospheric_dispersions, dependent: :destroy
  has_many :plume_calculations, through: :atmospheric_dispersions
  has_many :concentration_contours, through: :atmospheric_dispersions
  has_many :receptor_calculations, through: :atmospheric_dispersions
  
  accepts_nested_attributes_for :source_details
  
  validates :name, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[direct puddle tank pipeline] }
  validates :latitude, :longitude, presence: true, numericality: true
  validates :duration_minutes, presence: true, numericality: { in: 1..60 }
  validates :ambient_temperature, presence: true, numericality: { greater_than: 0 }
  validates :wind_speed, presence: true, numericality: { greater_than_or_equal_to: 1 }
  validates :stability_class, inclusion: { in: %w[A B C D E F] }
  validates :surface_roughness, inclusion: { in: %w[open_country urban_forest open_water] }
  
  serialize :calculation_results, Hash
  serialize :calculation_errors, Array
  
  scope :by_source_type, ->(type) { where(source_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  scope :calculated, -> { where(calculation_status: 'completed') }
  scope :public_scenarios, -> { where(public_scenario: true) }
  
  before_validation :set_default_conditions
  after_create :create_source_details
  
  # Constants from ALOHA
  STEFAN_BOLTZMANN = 5.67e-8 # W/(m²·K⁴)
  SOLAR_CONSTANT = 1368 # W/m² at top of atmosphere
  GAS_CONSTANT = 8.314 # J/(mol·K)
  VON_KARMAN = 0.4 # von Kármán constant
  
  # Surface roughness lengths (m) from ALOHA Table 7
  SURFACE_ROUGHNESS = {
    'open_country' => 0.03,
    'urban_forest' => 1.0,
    'open_water' => :calculated # based on wind speed
  }.freeze
  
  # Pasquill stability class parameters from ALOHA
  PASQUILL_PARAMETERS = {
    'A' => { n: 0.108, obukhov_factor: 11.4 },
    'B' => { n: 0.112, obukhov_factor: -26.0 },
    'C' => { n: 0.120, obukhov_factor: 123.0 },
    'D' => { n: 0.142, obukhov_factor: Float::INFINITY },
    'E' => { n: 0.203, obukhov_factor: 123.0 },
    'F' => { n: 0.253, obukhov_factor: 26.0 }
  }.freeze
  
  # Main calculation method - orchestrates source strength calculation
  def calculate_release!
    self.calculation_status = 'calculating'
    self.calculation_errors = []
    save!
    
    begin
      # Clear previous calculations
      release_calculations.destroy_all
      
      # Calculate time steps (up to 150 for variable releases, 5 for dispersion)
      time_steps = generate_time_steps
      
      # Calculate release for each time step based on source type
      time_steps.each do |step|
        case source_type
        when 'direct'
          calculate_direct_source(step)
        when 'puddle'
          calculate_puddle_source(step)
        when 'tank'
          calculate_tank_source(step)
        when 'pipeline'
          calculate_pipeline_source(step)
        end
      end
      
      # Average to 5 time steps for dispersion modeling
      average_to_dispersion_steps
      
      self.calculation_status = 'completed'
      self.last_calculated = Time.current
      
    rescue => e
      self.calculation_status = 'failed'
      self.calculation_errors << e.message
      Rails.logger.error "Scenario calculation failed: #{e.message}"
    ensure
      save!
    end
  end
  
  # Get surface roughness length in meters
  def surface_roughness_length
    if surface_roughness == 'open_water'
      # z0 = 0.0000026 * U10^2.5 for open water
      0.0000026 * (wind_speed ** 2.5)
    else
      SURFACE_ROUGHNESS[surface_roughness]
    end
  end
  
  # Calculate friction velocity U* using Deacon's formulation
  def friction_velocity
    roughness = surface_roughness_length
    return 0 if roughness <= 0
    
    # U* = 0.03 * U * (z/z0)^n for neutral conditions
    n = PASQUILL_PARAMETERS[stability_class][:n]
    0.03 * wind_speed * ((wind_reference_height / roughness) ** n)
  end
  
  # Calculate wind speed at given height using power law
  def wind_speed_at_height(height)
    return wind_speed if height == wind_reference_height
    
    n = PASQUILL_PARAMETERS[stability_class][:n]
    wind_speed * ((height / wind_reference_height) ** n)
  end
  
  # Calculate solar radiation flux (W/m²)
  def solar_radiation_flux
    return 0 unless start_time # Need time for solar calculations
    
    # Calculate solar altitude based on location and time
    solar_altitude = calculate_solar_altitude
    return 0 if solar_altitude <= 0.1
    
    # ALOHA solar radiation formula
    cloud_fraction = cloud_cover / 10.0
    incident_flux = SOLAR_CONSTANT * (1 - 0.75 * cloud_fraction) * Math.sin(solar_altitude)
    
    # Apply atmospheric transmissivity and ground albedo correction
    incident_flux * 0.85 # Average atmospheric transmissivity
  end
  
  # Calculate atmospheric pressure at elevation
  def atmospheric_pressure
    # Barometric formula: P = P0 * exp(-g*M*h/(R*T))
    p0 = 101325 # Sea level pressure (Pa)
    g = 9.8 # Gravity (m/s²)
    m = 0.029 # Molar mass of air (kg/mol)
    h = elevation || 0
    
    p0 * Math.exp(-g * m * h / (GAS_CONSTANT * ambient_temperature))
  end
  
  # Check if chemical forms dense gas at ambient conditions
  def dense_gas_conditions?
    chemical.dense_gas?(ambient_temperature, atmospheric_pressure)
  end
  
  # Get recommended dispersion model
  def recommended_dispersion_model
    chemical.recommended_dispersion_model(ambient_temperature, atmospheric_pressure)
  end
  
  # Calculate critical Richardson number for dispersion model selection
  def critical_richardson_number
    return 0 unless source_details
    
    reduced_gravity = chemical.reduced_gravity(ambient_temperature, atmospheric_pressure)
    return 0 if reduced_gravity <= 0
    
    friction_u = friction_velocity
    return Float::INFINITY if friction_u <= 0
    
    # Characteristic height depends on source type
    char_height = characteristic_source_height
    
    reduced_gravity * char_height / (friction_u ** 2)
  end
  
  # Calculate Level of Concern for threat zone calculation
  def level_of_concern(severity = 3)
    chemical.primary_emergency_guideline(duration_minutes) ||
    chemical.toxicological_data.first&.level_of_concern(duration_minutes, severity)
  end
  
  # Export scenario for external calculations
  def export_parameters
    {
      chemical: {
        name: chemical.name,
        cas_number: chemical.cas_number,
        molecular_weight: chemical.molecular_weight,
        properties: chemical.attributes.slice(*chemical.class.column_names)
      },
      scenario: attributes,
      source: source_details&.attributes,
      environmental: {
        pressure: atmospheric_pressure,
        solar_flux: solar_radiation_flux,
        roughness_length: surface_roughness_length,
        friction_velocity: friction_velocity
      }
    }
  end
  
  private
  
  def set_default_conditions
    self.ambient_temperature ||= 288.15 # 15°C
    self.ambient_pressure ||= atmospheric_pressure
    self.wind_reference_height ||= 10.0
    self.stability_class ||= determine_stability_class if wind_speed && start_time
    self.roughness_length = surface_roughness_length
  end
  
  def create_source_details
    build_source_details.save! unless source_details.present?
  end
  
  def generate_time_steps
    if instantaneous_release?
      [60] # Single 1-minute release
    else
      # Generate time steps for variable release (every minute up to duration)
      (60..duration_minutes * 60).step(60).to_a
    end
  end
  
  def characteristic_source_height
    case source_type
    when 'direct'
      release_height || 0
    when 'puddle'
      # H = E / (ρ * U10 * D) for puddle sources
      return 1.0 unless source_details
      
      evap_rate = source_details.calculate_evaporation_rate || 0.001
      density = chemical.gas_density(ambient_temperature, atmospheric_pressure) || 1.0
      diameter = source_details.puddle_diameter || 1.0
      
      evap_rate / (density * wind_speed * diameter)
    when 'tank', 'pipeline'
      # H = E / (ρ * U10 * π/4) for continuous sources
      return 1.0 unless source_details
      
      release_rate = source_details.calculate_mass_flow_rate || 0.001
      density = chemical.gas_density(ambient_temperature, atmospheric_pressure) || 1.0
      
      release_rate / (density * wind_speed * Math::PI / 4)
    else
      1.0
    end
  end
  
  def calculate_solar_altitude
    return 0 unless start_time && latitude && longitude
    
    # Simplified solar altitude calculation
    # In a full implementation, this would use proper astronomical calculations
    hour_angle = (start_time.hour - 12) * 15 * Math::PI / 180
    declination = 23.45 * Math::PI / 180 * Math.sin(2 * Math::PI * (start_time.yday - 81) / 365)
    lat_rad = latitude * Math::PI / 180
    
    Math.asin(Math.sin(lat_rad) * Math.sin(declination) + 
              Math.cos(lat_rad) * Math.cos(declination) * Math.cos(hour_angle))
  end
  
  def determine_stability_class
    # Simplified stability class determination based on wind speed and time
    # Full implementation would use solar radiation and cloud cover
    
    if start_time
      hour = start_time.hour
      if hour >= 7 && hour <= 17 # Daytime
        case wind_speed
        when 0..2 then 'A'
        when 2..3 then 'B'
        when 3..5 then 'C'
        when 5..6 then 'D'
        else 'D'
        end
      else # Nighttime
        case wind_speed
        when 0..2 then 'F'
        when 2..3 then 'E'
        when 3..5 then 'E'
        else 'D'
        end
      end
    else
      'D' # Neutral default
    end
  end
  
  def calculate_direct_source(time_step)
    # Direct source is user-specified release rate
    return unless source_details
    
    release_calculations.create!(
      time_step: time_step,
      mass_flow_rate: source_details.direct_release_rate || 0,
      temperature: ambient_temperature,
      pressure: atmospheric_pressure,
      density: chemical.gas_density(ambient_temperature, atmospheric_pressure)
    )
  end
  
  def calculate_puddle_source(time_step)
    source_details.calculate_puddle_evaporation(self, time_step)
  end
  
  def calculate_tank_source(time_step)
    source_details.calculate_tank_release(self, time_step)
  end
  
  def calculate_pipeline_source(time_step)
    source_details.calculate_pipeline_release(self, time_step)
  end
  
  def average_to_dispersion_steps
    # Average time-varying release to 5 steady-state steps for dispersion modeling
    total_steps = release_calculations.count
    return if total_steps <= 5
    
    # Group calculations into 5 bins and average each bin
    bin_size = total_steps / 5
    
    (0..4).each do |bin|
      start_step = bin * bin_size
      end_step = (bin + 1) * bin_size - 1
      end_step = total_steps - 1 if bin == 4 # Last bin gets remainder
      
      calcs_in_bin = release_calculations.offset(start_step).limit(end_step - start_step + 1)
      
      # Average the calculations in this bin
      avg_mass_flow = calcs_in_bin.average(:mass_flow_rate) || 0
      avg_temp = calcs_in_bin.average(:temperature) || ambient_temperature
      
      # Store averaged result (simplified for now)
      calculation_results["step_#{bin}"] = {
        mass_flow_rate: avg_mass_flow,
        temperature: avg_temp,
        duration: duration_minutes * 60 / 5
      }
    end
  end
end