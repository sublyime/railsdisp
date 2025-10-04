# Atmospheric Profile model for vertical atmospheric structure and boundary layer parameters
# Stores vertical profiles of meteorological parameters and derived dispersion parameters
class AtmosphericProfile < ApplicationRecord
  belongs_to :weather_observation
  
  # Delegate observation information for convenience
  delegate :weather_station, :observed_at, :dispersion_scenario, to: :weather_observation
  delegate :latitude, :longitude, :station_id, to: :weather_station
  
  # Validations
  validates :profile_type, presence: true, inclusion: { 
    in: %w[radiosonde model estimated lidar sodar tower synthetic] 
  }
  validates :profile_time, presence: true
  validates :surface_elevation, numericality: { greater_than: -500 }, allow_nil: true
  validates :boundary_layer_height, numericality: { greater_than: 0 }, allow_nil: true
  validates :surface_roughness, numericality: { greater_than: 0 }, allow_nil: true
  validates :atmospheric_stability_category, inclusion: { 
    in: %w[very_unstable unstable neutral stable very_stable] 
  }, allow_nil: true
  
  # Scopes for querying
  scope :by_type, ->(type) { where(profile_type: type) }
  scope :recent, -> { where('profile_time > ?', 12.hours.ago) }
  scope :today, -> { where('profile_time > ?', 24.hours.ago) }
  scope :with_boundary_layer, -> { where.not(boundary_layer_height: nil) }
  scope :radiosondes, -> { where(profile_type: 'radiosonde') }
  scope :model_profiles, -> { where(profile_type: 'model') }
  scope :estimated_profiles, -> { where(profile_type: 'estimated') }
  
  # JSON field accessors with defaults
  def height_levels
    parse_json_array(self[:height_levels]) || []
  end
  
  def temperature_profile
    parse_json_array(self[:temperature_profile]) || []
  end
  
  def wind_speed_profile
    parse_json_array(self[:wind_speed_profile]) || []
  end
  
  def wind_direction_profile
    parse_json_array(self[:wind_direction_profile]) || []
  end
  
  def humidity_profile
    parse_json_array(self[:humidity_profile]) || []
  end
  
  def pressure_profile
    parse_json_array(self[:pressure_profile]) || []
  end
  
  # Set profile data arrays
  def set_profile_data(heights:, temperatures: nil, wind_speeds: nil, wind_directions: nil, 
                      humidities: nil, pressures: nil)
    self.height_levels = heights.to_json
    self.temperature_profile = temperatures.to_json if temperatures
    self.wind_speed_profile = wind_speeds.to_json if wind_speeds
    self.wind_direction_profile = wind_directions.to_json if wind_directions
    self.humidity_profile = humidities.to_json if humidities
    self.pressure_profile = pressures.to_json if pressures
  end
  
  # Get complete profile data structure
  def profile_data
    levels = height_levels
    return {} if levels.empty?
    
    data = { heights: levels }
    data[:temperatures] = temperature_profile if temperature_profile.any?
    data[:wind_speeds] = wind_speed_profile if wind_speed_profile.any?
    data[:wind_directions] = wind_direction_profile if wind_direction_profile.any?
    data[:humidities] = humidity_profile if humidity_profile.any?
    data[:pressures] = pressure_profile if pressure_profile.any?
    
    data
  end
  
  # Get profile value at specific height using interpolation
  def interpolate_at_height(height_agl, parameter)
    heights = height_levels
    values = case parameter.to_sym
            when :temperature then temperature_profile
            when :wind_speed then wind_speed_profile
            when :wind_direction then wind_direction_profile
            when :humidity then humidity_profile
            when :pressure then pressure_profile
            else return nil
            end
    
    return nil if heights.empty? || values.empty? || heights.length != values.length
    
    # Handle special case of wind direction (circular interpolation)
    if parameter.to_sym == :wind_direction
      return interpolate_circular(height_agl, heights, values)
    end
    
    # Linear interpolation for other parameters
    interpolate_linear(height_agl, heights, values)
  end
  
  # Calculate atmospheric boundary layer characteristics
  def calculate_boundary_layer_parameters!
    heights = height_levels
    temps = temperature_profile
    winds = wind_speed_profile
    
    return unless heights.any? && temps.any? && winds.any?
    
    # Calculate boundary layer height if not provided
    self.boundary_layer_height ||= calculate_boundary_layer_height(heights, temps, winds)
    
    # Calculate surface roughness if not provided
    self.surface_roughness ||= estimate_surface_roughness
    
    # Calculate surface fluxes
    calc_heat_flux = calculate_surface_heat_flux(heights, temps)
    self.heat_flux_surface = calc_heat_flux if calc_heat_flux
    
    calc_momentum_flux = calculate_surface_momentum_flux(heights, winds)
    self.momentum_flux_surface = calc_momentum_flux if calc_momentum_flux
    
    # Calculate Richardson numbers
    calc_bulk_ri = calculate_bulk_richardson_number_profile(heights, temps, winds)
    self.bulk_richardson_number = calc_bulk_ri if calc_bulk_ri
    
    calc_grad_ri = calculate_gradient_richardson_number(heights, temps, winds)
    self.gradient_richardson_number = calc_grad_ri if calc_grad_ri
    
    # Determine atmospheric stability
    self.atmospheric_stability_category = determine_atmospheric_stability
    
    # Calculate dispersion parameters
    calc_vertical_rate = calculate_vertical_dispersion_rate
    self.vertical_dispersion_rate = calc_vertical_rate if calc_vertical_rate
    
    calc_horizontal_rate = calculate_horizontal_dispersion_rate
    self.horizontal_dispersion_rate = calc_horizontal_rate if calc_horizontal_rate
    
    calc_plume_factor = calculate_plume_rise_factor
    self.plume_rise_factor = calc_plume_factor if calc_plume_factor
    
    save!
  end
  
  # Calculate boundary layer height from temperature and wind profiles
  def calculate_boundary_layer_height(heights, temperatures, wind_speeds)
    return nil if heights.length < 3
    
    # Method 1: Find temperature inversion
    inversion_height = find_temperature_inversion(heights, temperatures)
    
    # Method 2: Find wind speed maximum (if present)
    wind_max_height = find_wind_speed_maximum(heights, wind_speeds)
    
    # Method 3: Use Richardson number criterion
    ri_height = find_richardson_criterion_height(heights, temperatures, wind_speeds)
    
    # Use the most reliable estimate
    candidates = [inversion_height, wind_max_height, ri_height].compact
    return 1000.0 if candidates.empty? # Default 1 km if no clear boundary
    
    # Return median of available estimates
    candidates.sort[candidates.length / 2]
  end
  
  # Find temperature inversion height
  def find_temperature_inversion(heights, temperatures)
    return nil if heights.length != temperatures.length || heights.length < 3
    
    # Look for first significant temperature increase with height
    (1...temperatures.length).each do |i|
      temp_gradient = (temperatures[i] - temperatures[i-1]) / (heights[i] - heights[i-1])
      
      # Inversion criterion: temperature increase > 0.002 K/m (2°C/km)
      if temp_gradient > 0.002
        return heights[i]
      end
    end
    
    nil
  end
  
  # Find wind speed maximum height (jet level)
  def find_wind_speed_maximum(heights, wind_speeds)
    return nil if heights.length != wind_speeds.length || heights.length < 3
    
    max_wind = wind_speeds.max
    max_index = wind_speeds.index(max_wind)
    
    # Only consider significant wind maxima above 100m
    return nil unless max_index && heights[max_index] > 100
    
    heights[max_index]
  end
  
  # Find boundary layer height using Richardson number criterion
  def find_richardson_criterion_height(heights, temperatures, wind_speeds)
    return nil if heights.length < 3
    
    # Richardson number > 0.25 typically indicates stable boundary layer top
    ri_critical = 0.25
    
    (2...heights.length).each do |i|
      ri = calculate_local_richardson_number(heights, temperatures, wind_speeds, i)
      next unless ri
      
      if ri > ri_critical && heights[i] > 50 # Above 50m minimum
        return heights[i]
      end
    end
    
    nil
  end
  
  # Calculate local Richardson number at a specific level
  def calculate_local_richardson_number(heights, temps, winds, index)
    return nil if index < 1 || index >= heights.length
    
    # Ri = (g/T) * (dT/dz) / (du/dz)²
    g = 9.81
    
    # Calculate gradients
    dz = heights[index] - heights[index-1]
    dt = temps[index] - temps[index-1]
    du = winds[index] - winds[index-1]
    
    return nil if dz <= 0 || du.abs < 0.1
    
    t_mean = (temps[index] + temps[index-1]) / 2.0 + 273.15 # Convert to Kelvin
    dt_dz = dt / dz
    du_dz = du / dz
    
    (g / t_mean) * dt_dz / (du_dz**2)
  end
  
  # Determine atmospheric stability from profile analysis
  def determine_atmospheric_stability
    return atmospheric_stability_category if atmospheric_stability_category.present?
    
    # Use Richardson number if available
    if bulk_richardson_number.present?
      ri = bulk_richardson_number
      return case ri
            when Float::NEGATIVE_INFINITY..-0.5 then 'very_unstable'
            when -0.5..-0.1 then 'unstable'
            when -0.1..0.1 then 'neutral'
            when 0.1..0.5 then 'stable'
            else 'very_stable'
            end
    end
    
    # Use temperature gradient analysis
    heights = height_levels
    temps = temperature_profile
    
    if heights.any? && temps.any? && heights.length == temps.length
      # Calculate average lapse rate in lower boundary layer
      surface_temp = temps[0]
      
      # Find temperature at ~100m if available
      temp_100m = interpolate_at_height(100, :temperature)
      
      if temp_100m
        lapse_rate = (surface_temp - temp_100m) / 100.0 # K/100m
        
        case lapse_rate
        when 1.5..Float::INFINITY then 'very_unstable' # Super-adiabatic
        when 0.8..1.5 then 'unstable' # Unstable
        when 0.6..0.8 then 'neutral' # Near neutral
        when -0.5..0.6 then 'stable' # Stable
        else 'very_stable' # Strong inversion
        end
      else
        'neutral' # Default
      end
    else
      'neutral' # Default when insufficient data
    end
  end
  
  # Calculate surface heat flux from temperature profile
  def calculate_surface_heat_flux(heights, temperatures)
    return heat_flux_surface if heat_flux_surface.present?
    return nil if heights.length < 2 || temperatures.length < 2
    
    # Estimate from surface temperature gradient
    dz = heights[1] - heights[0]
    dt = temperatures[1] - temperatures[0]
    
    return nil if dz <= 0
    
    # Simple gradient-based estimate
    # H ≈ -ρ * cp * κ * u* * (dT/dz)
    rho = 1.225 # kg/m³
    cp = 1004.0 # J/kg/K
    kappa = 0.4
    u_star = 0.3 # Estimated friction velocity
    
    dt_dz = dt / dz
    
    -rho * cp * kappa * u_star * dt_dz
  end
  
  # Calculate surface momentum flux from wind profile
  def calculate_surface_momentum_flux(heights, wind_speeds)
    return momentum_flux_surface if momentum_flux_surface.present?
    return nil if heights.length < 2 || wind_speeds.length < 2
    
    # Calculate wind shear
    dz = heights[1] - heights[0]
    du = wind_speeds[1] - wind_speeds[0]
    
    return nil if dz <= 0
    
    # τ = ρ * u*² where u* estimated from wind shear
    rho = 1.225 # kg/m³
    kappa = 0.4
    
    # u* = κ * u / ln(z/z0)
    z = heights[1]
    z0 = surface_roughness || 0.1
    u_star = kappa * wind_speeds[0] / Math.log(z / z0)
    
    rho * u_star**2
  end
  
  # Estimate surface roughness from wind profile
  def estimate_surface_roughness
    return surface_roughness if surface_roughness.present?
    
    winds = wind_speed_profile
    heights = height_levels
    
    return 0.1 if winds.empty? || heights.empty? || winds.length < 2
    
    # Use logarithmic wind profile: u(z) = (u*/κ) * ln(z/z0)
    # Solve for z0 using two levels
    
    u1, u2 = winds[0], winds[1]
    z1, z2 = heights[0], heights[1]
    
    return 0.1 if u1 <= 0 || u2 <= 0 || z1 <= 0 || z2 <= 0 || u1 == u2
    
    # z0 = z1 / exp(κ * u1 / u*)
    # where u* = κ * (u2 - u1) / ln(z2/z1)
    
    kappa = 0.4
    u_star = kappa * (u2 - u1) / Math.log(z2 / z1)
    
    return 0.1 if u_star <= 0
    
    z0 = z1 / Math.exp(kappa * u1 / u_star)
    
    # Constrain to reasonable values
    [[z0, 0.001].max, 2.0].min
  end
  
  # Calculate vertical dispersion rate
  def calculate_vertical_dispersion_rate
    return nil unless boundary_layer_height.present?
    
    stability = atmospheric_stability_category || determine_atmospheric_stability
    
    # Dispersion rate depends on stability and boundary layer height
    base_rate = case stability
               when 'very_unstable' then 1000.0 # m²/s
               when 'unstable' then 500.0
               when 'neutral' then 200.0
               when 'stable' then 50.0
               when 'very_stable' then 10.0
               else 200.0
               end
    
    # Scale by boundary layer height
    bl_factor = boundary_layer_height / 1000.0 # Normalize to 1 km
    base_rate * bl_factor
  end
  
  # Calculate horizontal dispersion rate
  def calculate_horizontal_dispersion_rate
    return nil unless boundary_layer_height.present?
    
    stability = atmospheric_stability_category || determine_atmospheric_stability
    
    # Horizontal dispersion typically larger than vertical
    vertical_rate = calculate_vertical_dispersion_rate || 200.0
    
    horizontal_factor = case stability
                       when 'very_unstable' then 3.0
                       when 'unstable' then 2.5
                       when 'neutral' then 2.0
                       when 'stable' then 1.5
                       when 'very_stable' then 1.2
                       else 2.0
                       end
    
    vertical_rate * horizontal_factor
  end
  
  # Calculate plume rise enhancement factor
  def calculate_plume_rise_factor
    stability = atmospheric_stability_category || determine_atmospheric_stability
    
    # Plume rise depends on atmospheric stability
    case stability
    when 'very_unstable' then 2.0 # Strong convection enhances rise
    when 'unstable' then 1.5
    when 'neutral' then 1.0
    when 'stable' then 0.7 # Inversion suppresses rise
    when 'very_stable' then 0.4
    else 1.0
    end
  end
  
  # Generate dispersion parameters for atmospheric models
  def generate_dispersion_parameters(release_height = 10.0)
    calculate_boundary_layer_parameters! unless boundary_layer_height.present?
    
    {
      profile_info: {
        type: profile_type,
        profile_time: profile_time,
        boundary_layer_height: boundary_layer_height,
        surface_roughness: surface_roughness
      },
      atmospheric_stability: {
        category: atmospheric_stability_category,
        bulk_richardson_number: bulk_richardson_number,
        gradient_richardson_number: gradient_richardson_number
      },
      surface_fluxes: {
        heat_flux: heat_flux_surface,
        momentum_flux: momentum_flux_surface
      },
      dispersion_rates: {
        vertical: vertical_dispersion_rate,
        horizontal: horizontal_dispersion_rate,
        plume_rise_factor: plume_rise_factor
      },
      wind_profile: generate_wind_profile_parameters(release_height),
      mixing_parameters: calculate_mixing_parameters
    }
  end
  
  # Generate wind profile parameters for release height
  def generate_wind_profile_parameters(release_height)
    # Interpolate wind at release height
    wind_speed_at_release = interpolate_at_height(release_height, :wind_speed)
    wind_direction_at_release = interpolate_at_height(release_height, :wind_direction)
    
    # Calculate wind shear parameters
    wind_shear = calculate_wind_shear_at_height(release_height)
    
    {
      wind_speed: wind_speed_at_release,
      wind_direction: wind_direction_at_release,
      wind_shear: wind_shear,
      surface_wind_speed: interpolate_at_height(10.0, :wind_speed),
      friction_velocity: estimate_friction_velocity_from_profile
    }
  end
  
  # Calculate wind shear at specific height
  def calculate_wind_shear_at_height(height)
    heights = height_levels
    winds = wind_speed_profile
    
    return nil if heights.empty? || winds.empty?
    
    # Find the layer containing the specified height
    layer_index = heights.index { |h| h > height }
    return nil unless layer_index && layer_index > 0
    
    # Calculate shear in the layer
    dz = heights[layer_index] - heights[layer_index - 1]
    du = winds[layer_index] - winds[layer_index - 1]
    
    return nil if dz <= 0
    
    du / dz # 1/s
  end
  
  # Estimate friction velocity from wind profile
  def estimate_friction_velocity_from_profile
    surface_wind = interpolate_at_height(10.0, :wind_speed)
    return nil unless surface_wind
    
    z0 = surface_roughness || 0.1
    kappa = 0.4
    z = 10.0
    
    surface_wind * kappa / Math.log(z / z0)
  end
  
  # Calculate mixing parameters for dispersion
  def calculate_mixing_parameters
    {
      mixing_height: boundary_layer_height,
      capping_inversion_strength: calculate_inversion_strength,
      convective_velocity_scale: calculate_convective_velocity_scale,
      mechanical_mixing_factor: calculate_mechanical_mixing_factor
    }
  end
  
  # Calculate temperature inversion strength
  def calculate_inversion_strength
    return nil unless capping_inversion_height.present?
    
    heights = height_levels
    temps = temperature_profile
    
    return nil if heights.empty? || temps.empty?
    
    # Find temperature jump across inversion
    inversion_base_temp = interpolate_at_height(capping_inversion_height, :temperature)
    inversion_top_temp = interpolate_at_height(capping_inversion_height + 100, :temperature)
    
    return nil unless inversion_base_temp && inversion_top_temp
    
    # Temperature increase across inversion (K)
    inversion_top_temp - inversion_base_temp
  end
  
  # Calculate convective velocity scale
  def calculate_convective_velocity_scale
    return nil unless heat_flux_surface.present? && boundary_layer_height.present?
    
    # w* = (g * H * zi / (ρ * cp * T))^(1/3)
    g = 9.81
    h = heat_flux_surface
    zi = boundary_layer_height
    rho = 1.225
    cp = 1004.0
    t = (interpolate_at_height(10.0, :temperature) || 15.0) + 273.15
    
    return nil if h <= 0 # Only for unstable conditions
    
    ((g * h * zi) / (rho * cp * t))**(1.0/3.0)
  end
  
  # Calculate mechanical mixing factor
  def calculate_mechanical_mixing_factor
    friction_vel = estimate_friction_velocity_from_profile
    return 1.0 unless friction_vel && boundary_layer_height.present?
    
    # Dimensionless ratio u*/w*
    convective_vel = calculate_convective_velocity_scale
    
    if convective_vel && convective_vel > 0
      friction_vel / convective_vel
    else
      # Purely mechanical turbulence
      [friction_vel / 0.3, 3.0].min # Cap at reasonable value
    end
  end
  
  # Export profile for visualization
  def to_visualization_data
    profile_levels = []
    heights = height_levels
    
    heights.each_with_index do |height, i|
      level_data = { height: height }
      
      level_data[:temperature] = temperature_profile[i] if temperature_profile[i]
      level_data[:wind_speed] = wind_speed_profile[i] if wind_speed_profile[i]
      level_data[:wind_direction] = wind_direction_profile[i] if wind_direction_profile[i]
      level_data[:humidity] = humidity_profile[i] if humidity_profile[i]
      level_data[:pressure] = pressure_profile[i] if pressure_profile[i]
      
      profile_levels << level_data
    end
    
    {
      profile_metadata: {
        type: profile_type,
        time: profile_time,
        location: [latitude, longitude],
        surface_elevation: surface_elevation
      },
      boundary_layer: {
        height: boundary_layer_height,
        stability: atmospheric_stability_category,
        surface_roughness: surface_roughness
      },
      profile_data: profile_levels
    }
  end
  
  # Create estimated profile from surface observation
  def self.create_estimated_profile(weather_observation, max_height = 3000)
    surface_obs = weather_observation
    
    # Generate height levels
    heights = [0, 10, 50, 100, 200, 500, 1000, 1500, 2000, max_height]
    
    # Estimate profiles based on stability class
    stability_class = surface_obs.pasquill_stability_class
    surface_temp = surface_obs.temperature
    surface_wind = surface_obs.wind_speed
    surface_direction = surface_obs.wind_direction
    
    return nil unless surface_temp && surface_wind && surface_direction
    
    # Create profile
    profile = create!(
      weather_observation: weather_observation,
      profile_type: 'estimated',
      profile_time: surface_obs.observed_at,
      surface_elevation: surface_obs.weather_station.elevation || 0
    )
    
    # Generate estimated temperature profile
    temps = generate_estimated_temperature_profile(heights, surface_temp, stability_class)
    
    # Generate estimated wind profile
    winds = generate_estimated_wind_profile(heights, surface_wind, stability_class)
    wind_dirs = Array.new(heights.length, surface_direction) # Assume constant direction
    
    # Set profile data
    profile.set_profile_data(
      heights: heights,
      temperatures: temps,
      wind_speeds: winds,
      wind_directions: wind_dirs
    )
    
    # Calculate derived parameters
    profile.calculate_boundary_layer_parameters!
    
    profile
  end
  
  private
  
  # Parse JSON array with error handling
  def parse_json_array(json_string)
    return [] if json_string.blank?
    
    if json_string.is_a?(Array)
      json_string
    else
      JSON.parse(json_string)
    end
  rescue JSON::ParserError
    []
  end
  
  # Linear interpolation between points
  def interpolate_linear(target_height, heights, values)
    return nil if heights.empty? || values.empty?
    return values[0] if heights.length == 1
    
    # Find surrounding points
    if target_height <= heights[0]
      return values[0]
    elsif target_height >= heights[-1]
      return values[-1]
    end
    
    # Find bracketing indices
    upper_index = heights.index { |h| h > target_height }
    return values[-1] unless upper_index
    
    lower_index = upper_index - 1
    
    # Linear interpolation
    h1, h2 = heights[lower_index], heights[upper_index]
    v1, v2 = values[lower_index], values[upper_index]
    
    v1 + (v2 - v1) * (target_height - h1) / (h2 - h1)
  end
  
  # Circular interpolation for wind direction
  def interpolate_circular(target_height, heights, directions)
    return nil if heights.empty? || directions.empty?
    return directions[0] if heights.length == 1
    
    # Convert to vectors for interpolation
    sin_dirs = directions.map { |d| Math.sin(d * Math::PI / 180) }
    cos_dirs = directions.map { |d| Math.cos(d * Math::PI / 180) }
    
    # Interpolate vector components
    sin_interp = interpolate_linear(target_height, heights, sin_dirs)
    cos_interp = interpolate_linear(target_height, heights, cos_dirs)
    
    return nil unless sin_interp && cos_interp
    
    # Convert back to direction
    direction = Math.atan2(sin_interp, cos_interp) * 180 / Math::PI
    direction += 360 if direction < 0
    direction
  end
  
  # Generate estimated temperature profile
  def self.generate_estimated_temperature_profile(heights, surface_temp, stability_class)
    # Lapse rates by stability class (K/100m)
    lapse_rates = {
      'A' => 1.5,   # Superadiabatic
      'B' => 1.2,   # Unstable
      'C' => 0.9,   # Slightly unstable
      'D' => 0.65,  # Neutral (dry adiabatic)
      'E' => 0.3,   # Slightly stable
      'F' => -0.5   # Stable inversion
    }
    
    lapse_rate = lapse_rates[stability_class] || 0.65
    
    heights.map do |height|
      surface_temp - (lapse_rate * height / 100.0)
    end
  end
  
  # Generate estimated wind profile
  def self.generate_estimated_wind_profile(heights, surface_wind, stability_class)
    # Power law exponents by stability class
    power_exponents = {
      'A' => 0.10,  # Low shear in unstable conditions
      'B' => 0.15,
      'C' => 0.20,
      'D' => 0.25,  # Neutral conditions
      'E' => 0.35,
      'F' => 0.50   # High shear in stable conditions
    }
    
    exponent = power_exponents[stability_class] || 0.25
    reference_height = 10.0 # Reference height for surface wind
    
    heights.map do |height|
      if height <= reference_height
        surface_wind * (height / reference_height)**exponent
      else
        surface_wind * (height / reference_height)**exponent
      end
    end
  end
end