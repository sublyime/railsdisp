class DispersionCalculation < ApplicationRecord
  belongs_to :dispersion_event
  belongs_to :weather_datum
  
  validates :calculation_timestamp, presence: true
  validates :model_used, presence: true, inclusion: { 
    in: %w[gaussian puff lagrangian cfd_simplified] 
  }
  validates :stability_class, presence: true, inclusion: { 
    in: %w[A B C D E F] 
  }
  validates :effective_height, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_concentration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_distance, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :recent, -> { where('calculation_timestamp >= ?', 1.hour.ago) }
  scope :by_model, ->(model) { where(model_used: model) }
  scope :by_stability, ->(stability) { where(stability_class: stability) }
  
  before_create :set_calculation_timestamp
  before_save :calculate_dispersion_parameters
  after_create :update_receptor_concentrations
  
  def plume_centerline_concentration(distance)
    return 0 if distance <= 0 || !plume_data.present?
    
    # Extract plume data for concentration calculation
    source_strength = dispersion_event.source_strength
    wind_speed = weather_datum.wind_speed
    
    # Gaussian plume model simplified calculation
    dispersion_y = lateral_dispersion_coefficient(distance)
    dispersion_z = vertical_dispersion_coefficient(distance)
    
    concentration = source_strength / (Math::PI * wind_speed * dispersion_y * dispersion_z)
    concentration * Math.exp(-((effective_height || 0)**2) / (2 * dispersion_z**2))
  end
  
  def concentration_at_point(x, y, z = 0)
    return 0 unless plume_data.present?
    
    # Transform coordinates to downwind distance and crosswind distance
    wind_dir_rad = weather_datum.wind_direction * Math::PI / 180
    
    # Rotate coordinates to wind direction
    downwind = x * Math.cos(wind_dir_rad) + y * Math.sin(wind_dir_rad)
    crosswind = -x * Math.sin(wind_dir_rad) + y * Math.cos(wind_dir_rad)
    
    return 0 if downwind <= 0
    
    # Gaussian plume calculation
    source_strength = dispersion_event.source_strength
    wind_speed = weather_datum.wind_speed
    
    dispersion_y = lateral_dispersion_coefficient(downwind)
    dispersion_z = vertical_dispersion_coefficient(downwind)
    
    # Centerline concentration
    centerline_conc = source_strength / (Math::PI * wind_speed * dispersion_y * dispersion_z)
    
    # Apply crosswind and vertical dispersion
    crosswind_factor = Math.exp(-(crosswind**2) / (2 * dispersion_y**2))
    
    height_factor = Math.exp(-((z - (effective_height || 0))**2) / (2 * dispersion_z**2)) +
                   Math.exp(-((z + (effective_height || 0))**2) / (2 * dispersion_z**2))
    
    centerline_conc * crosswind_factor * height_factor
  end
  
  def generate_plume_contours(concentration_levels = [0.1, 1.0, 10.0, 100.0])
    contours = []
    
    concentration_levels.each do |level|
      contour_points = []
      
      # Calculate contour points for this concentration level
      (0..3600).step(10).each do |angle_deg|
        angle_rad = angle_deg * Math::PI / 180
        
        # Binary search for distance at this angle where concentration equals level
        distance = find_distance_for_concentration(angle_rad, level)
        
        if distance > 0
          x = distance * Math.cos(angle_rad)
          y = distance * Math.sin(angle_rad)
          
          # Transform to lat/lon coordinates
          lat, lon = offset_to_coordinates(x, y)
          contour_points << [lat, lon]
        end
      end
      
      contours << {
        level: level,
        points: contour_points,
        color: concentration_color(level)
      } if contour_points.any?
    end
    
    contours
  end
  
  private
  
  def set_calculation_timestamp
    self.calculation_timestamp ||= Time.current
  end
  
  def calculate_dispersion_parameters
    self.stability_class ||= weather_datum.stability_class
    self.effective_height ||= calculate_effective_height
    self.max_concentration ||= calculate_max_concentration
    self.max_distance ||= calculate_max_distance
  end
  
  def calculate_effective_height
    # Stack height + plume rise due to momentum and buoyancy
    stack_height = dispersion_event.location.building_height || 0
    
    # Simplified plume rise calculation
    wind_speed = weather_datum.wind_speed
    temperature = weather_datum.temperature
    
    # Momentum rise (simplified)
    momentum_rise = 2.0 * wind_speed / (wind_speed + 3.0)
    
    stack_height + momentum_rise
  end
  
  def calculate_max_concentration
    # Maximum concentration typically occurs near the source
    distances = (10..1000).step(10).to_a
    max_conc = distances.map { |d| plume_centerline_concentration(d) }.max
    max_conc || 0
  end
  
  def calculate_max_distance
    # Distance where concentration drops below 1% of maximum
    threshold = (max_concentration || 0) * 0.01
    
    (10..10000).step(50).each do |distance|
      return distance if plume_centerline_concentration(distance) < threshold
    end
    
    10000 # Default max distance
  end
  
  def lateral_dispersion_coefficient(distance)
    # Pasquill-Gifford dispersion coefficients
    case stability_class
    when 'A' # Very unstable
      0.22 * distance * (1 + 0.0001 * distance)**(-0.5)
    when 'B' # Moderately unstable
      0.16 * distance * (1 + 0.0001 * distance)**(-0.5)
    when 'C' # Slightly unstable
      0.11 * distance * (1 + 0.0001 * distance)**(-0.5)
    when 'D' # Neutral
      0.08 * distance * (1 + 0.0001 * distance)**(-0.5)
    when 'E' # Slightly stable
      0.06 * distance * (1 + 0.0001 * distance)**(-0.5)
    when 'F' # Moderately stable
      0.04 * distance * (1 + 0.0001 * distance)**(-0.5)
    else
      0.08 * distance * (1 + 0.0001 * distance)**(-0.5)
    end
  end
  
  def vertical_dispersion_coefficient(distance)
    # Pasquill-Gifford vertical dispersion coefficients
    case stability_class
    when 'A'
      0.20 * distance
    when 'B'
      0.12 * distance
    when 'C'
      0.08 * distance * (1 + 0.0002 * distance)**(-0.5)
    when 'D'
      0.06 * distance * (1 + 0.0015 * distance)**(-0.5)
    when 'E'
      0.03 * distance * (1 + 0.0003 * distance)**(-1)
    when 'F'
      0.016 * distance * (1 + 0.0003 * distance)**(-1)
    else
      0.06 * distance * (1 + 0.0015 * distance)**(-0.5)
    end
  end
  
  def find_distance_for_concentration(angle, target_concentration)
    # Binary search for distance where concentration equals target
    min_dist = 1.0
    max_dist = 10000.0
    tolerance = 0.01
    
    while (max_dist - min_dist) > tolerance
      mid_dist = (min_dist + max_dist) / 2.0
      
      x = mid_dist * Math.cos(angle)
      y = mid_dist * Math.sin(angle)
      conc = concentration_at_point(x, y)
      
      if conc > target_concentration
        min_dist = mid_dist
      else
        max_dist = mid_dist
      end
    end
    
    min_dist
  end
  
  def offset_to_coordinates(x_offset, y_offset)
    # Convert x,y offset in meters to lat/lon coordinates
    source_lat = dispersion_event.location.latitude
    source_lon = dispersion_event.location.longitude
    
    # Earth radius in meters
    earth_radius = 6371000
    
    # Convert to degrees
    lat_offset = (y_offset / earth_radius) * (180 / Math::PI)
    lon_offset = (x_offset / earth_radius) * (180 / Math::PI) / Math.cos(source_lat * Math::PI / 180)
    
    [source_lat + lat_offset, source_lon + lon_offset]
  end
  
  def concentration_color(level)
    case level
    when 0...1
      '#00ff00'    # Green - safe
    when 1...10
      '#ffff00'    # Yellow - caution
    when 10...100
      '#ff8800'    # Orange - warning
    else
      '#ff0000'    # Red - danger
    end
  end
  
  def update_receptor_concentrations
    # Update all receptors for this dispersion event
    DispersionEvent.find(dispersion_event_id).receptors.find_each do |receptor|
      x = (receptor.longitude - dispersion_event.location.longitude) * 111320 * Math.cos(receptor.latitude * Math::PI / 180)
      y = (receptor.latitude - dispersion_event.location.latitude) * 110540
      
      concentration = concentration_at_point(x, y)
      receptor.update(concentration: concentration)
    end
  end
end
