class TerrainPoint < ApplicationRecord
  belongs_to :map_layer
  
  # Validations
  validates :latitude, presence: true, numericality: { 
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90 
  }
  validates :longitude, presence: true, numericality: { 
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180 
  }
  validates :elevation, presence: true, numericality: true
  validates :data_source, presence: true, inclusion: {
    in: %w[usgs srtm manual lidar survey interpolated]
  }
  
  # Callbacks
  before_validation :set_defaults
  
  # Scopes
  scope :in_bounds, ->(north, south, east, west) {
    where(latitude: south..north, longitude: west..east)
  }
  scope :measured, -> { where(interpolated: false) }
  scope :interpolated, -> { where(interpolated: true) }
  scope :by_source, ->(source) { where(data_source: source) }
  
  # Find nearest terrain points for interpolation
  def self.nearest_points(lat, lng, limit = 4)
    # Simple distance calculation - in production use spatial index
    select("*, 
            (6371 * acos(cos(radians(#{lat})) * cos(radians(latitude)) * 
                         cos(radians(longitude) - radians(#{lng})) + 
                         sin(radians(#{lat})) * sin(radians(latitude)))) as distance")
      .order('distance')
      .limit(limit)
  end
  
  # Interpolate elevation at a given point
  def self.interpolate_elevation(lat, lng, radius_km = 10)
    # Find nearby points within radius
    nearby_points = where(
      "(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * 
                    cos(radians(longitude) - radians(?)) + 
                    sin(radians(?)) * sin(radians(latitude)))) < ?",
      lat, lng, lat, radius_km
    )
    
    return nil if nearby_points.count < 3
    
    # Inverse distance weighting interpolation
    total_weight = 0
    weighted_elevation = 0
    
    nearby_points.each do |point|
      distance = point.distance_from(lat, lng)
      next if distance == 0 # Exact match
      
      weight = 1.0 / (distance ** 2)
      total_weight += weight
      weighted_elevation += point.elevation * weight
    end
    
    return nil if total_weight == 0
    
    weighted_elevation / total_weight
  end
  
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
  
  # Get slope/gradient to another point
  def slope_to(other_point)
    distance = distance_from(other_point.latitude, other_point.longitude)
    return 0 if distance == 0
    
    elevation_diff = other_point.elevation - elevation
    Math.atan(elevation_diff / distance) * (180 / Math::PI) # degrees
  end
  
  # Convert to GeoJSON
  def to_geojson
    {
      type: 'Feature',
      properties: {
        id: id,
        elevation: elevation,
        data_source: data_source,
        interpolated: interpolated
      },
      geometry: {
        type: 'Point',
        coordinates: [longitude, latitude, elevation]
      }
    }
  end
  
  private
  
  def set_defaults
    self.interpolated = false if interpolated.nil?
    self.data_source ||= 'manual'
  end
end
