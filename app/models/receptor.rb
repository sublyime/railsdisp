class Receptor < ApplicationRecord
  belongs_to :dispersion_event
  
  validates :name, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  validates :distance_from_source, numericality: { greater_than: 0 }, allow_nil: true
  validates :concentration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :exposure_time, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :health_impact_level, inclusion: { 
    in: %w[safe low moderate high critical] 
  }, allow_nil: true
  
  scope :with_concentration, -> { where.not(concentration: nil) }
  scope :high_risk, -> { where(health_impact_level: ['high', 'critical']) }
  scope :by_impact_level, ->(level) { where(health_impact_level: level) }
  
  before_save :calculate_distance_from_source
  before_save :assess_health_impact
  
  def coordinates
    [latitude, longitude]
  end
  
  def source_coordinates
    [dispersion_event.location.latitude, dispersion_event.location.longitude]
  end
  
  def safe?
    health_impact_level.in?(['safe', 'low']) || concentration.to_f < safety_threshold
  end
  
  def critical?
    health_impact_level == 'critical'
  end
  
  # Calculate bearing from source to receptor
  def bearing_from_source
    source_lat = dispersion_event.location.latitude * Math::PI / 180
    source_lon = dispersion_event.location.longitude * Math::PI / 180
    dest_lat = latitude * Math::PI / 180
    dest_lon = longitude * Math::PI / 180
    
    dlon = dest_lon - source_lon
    
    y = Math.sin(dlon) * Math.cos(dest_lat)
    x = Math.cos(source_lat) * Math.sin(dest_lat) - 
        Math.sin(source_lat) * Math.cos(dest_lat) * Math.cos(dlon)
    
    bearing = Math.atan2(y, x) * 180 / Math::PI
    (bearing + 360) % 360
  end
  
  private
  
  def calculate_distance_from_source
    return unless latitude && longitude && dispersion_event&.location
    
    # Haversine formula for distance calculation
    source_lat = dispersion_event.location.latitude * Math::PI / 180
    source_lon = dispersion_event.location.longitude * Math::PI / 180
    dest_lat = latitude * Math::PI / 180
    dest_lon = longitude * Math::PI / 180
    
    dlat = dest_lat - source_lat
    dlon = dest_lon - source_lon
    
    a = Math.sin(dlat/2)**2 + Math.cos(source_lat) * Math.cos(dest_lat) * Math.sin(dlon/2)**2
    c = 2 * Math.asin(Math.sqrt(a))
    
    # Earth radius in meters
    earth_radius = 6371000
    
    self.distance_from_source = earth_radius * c
  end
  
  def assess_health_impact
    return unless concentration.present?
    
    # Simple health impact assessment based on concentration
    # In reality, this would use chemical-specific toxicity data
    threshold = safety_threshold
    
    self.health_impact_level = case concentration
    when 0...threshold * 0.1
      'safe'
    when threshold * 0.1...threshold * 0.5
      'low'
    when threshold * 0.5...threshold
      'moderate'
    when threshold...threshold * 5
      'high'
    else
      'critical'
    end
  end
  
  def safety_threshold
    # Default safety threshold in mg/m³
    # This should be chemical-specific in a real application
    case dispersion_event.chemical.hazard_class
    when 'toxic'
      1.0
    when 'highly_toxic'
      0.1
    when 'corrosive'
      5.0
    else
      10.0
    end
  end
end
