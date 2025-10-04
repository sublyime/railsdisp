class Building < ApplicationRecord
  belongs_to :map_layer
  
  # Validations
  validates :name, presence: true
  validates :building_type, presence: true, inclusion: {
    in: %w[residential commercial industrial office warehouse hospital school factory storage administrative]
  }
  validates :latitude, presence: true, numericality: { 
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90 
  }
  validates :longitude, presence: true, numericality: { 
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180 
  }
  validates :height, numericality: { greater_than: 0 }, allow_nil: true
  validates :area, numericality: { greater_than: 0 }, allow_nil: true
  
  # Callbacks
  before_save :update_geometry
  
  # Scopes
  scope :in_bounds, ->(north, south, east, west) {
    where(latitude: south..north, longitude: west..east)
  }
  scope :by_type, ->(type) { where(building_type: type) }
  scope :tall_buildings, -> { where('height > ?', 50) }
  
  # JSON serialization for geometry
  serialize :geometry, coder: JSON
  
  # Calculate distance from a point (Haversine formula)
  def distance_from(lat, lng)
    rad_per_deg = Math::PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # in meters
    
    dlat_rad = (lat - latitude) * rad_per_deg
    dlon_rad = (lng - longitude) * rad_per_deg
    
    lat1_rad = latitude * rad_per_deg
    lat2_rad = lat * rad_per_deg
    
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rm * c # Distance in meters
  end
  
  # Check if building affects wind flow at a given height
  def affects_wind_at_height?(wind_height)
    return false unless height.present?
    height >= wind_height * 0.5 # Building affects wind if it's at least 50% of wind height
  end
  
  # Get building footprint as GeoJSON
  def to_geojson
    {
      type: 'Feature',
      properties: {
        id: id,
        name: name,
        building_type: building_type,
        height: height,
        area: area
      },
      geometry: parsed_geometry || point_geometry
    }
  end
  
  private
  
  def update_geometry
    if geometry.blank?
      self.geometry = point_geometry
    end
  end
  
  def parsed_geometry
    return nil if geometry.blank?
    geometry.is_a?(String) ? JSON.parse(geometry) : geometry
  rescue JSON::ParserError
    nil
  end
  
  def point_geometry
    {
      type: 'Point',
      coordinates: [longitude, latitude]
    }
  end
end
