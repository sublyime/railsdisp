class GisFeature < ApplicationRecord
  belongs_to :map_layer
  
  # Validations
  validates :name, presence: true
  validates :feature_type, presence: true, inclusion: {
    in: %w[point line polygon boundary zone water road railway pipeline powerline emergency_zone restricted_area]
  }
  validates :latitude, presence: true, numericality: { 
    greater_than_or_equal_to: -90, less_than_or_equal_to: 90 
  }, if: :point_feature?
  validates :longitude, presence: true, numericality: { 
    greater_than_or_equal_to: -180, less_than_or_equal_to: 180 
  }, if: :point_feature?
  
  # Callbacks
  before_save :update_center_point
  before_validation :set_defaults
  
  # Scopes
  scope :in_bounds, ->(north, south, east, west) {
    where(latitude: south..north, longitude: west..east)
  }
  scope :by_type, ->(type) { where(feature_type: type) }
  scope :boundaries, -> { where(feature_type: 'boundary') }
  scope :infrastructure, -> { where(feature_type: %w[road railway pipeline powerline]) }
  scope :zones, -> { where(feature_type: %w[zone emergency_zone restricted_area]) }
  
  # JSON serialization
  serialize :properties, coder: JSON
  serialize :geometry, coder: JSON
  
  def properties
    super || {}
  end
  
  def geometry
    parsed = super
    return point_geometry if parsed.blank? && point_feature?
    parsed
  end
  
  # Check if feature is a point
  def point_feature?
    %w[point].include?(feature_type)
  end
  
  # Check if feature is linear
  def linear_feature?
    %w[line road railway pipeline powerline].include?(feature_type)
  end
  
  # Check if feature is a polygon
  def polygon_feature?
    %w[polygon boundary zone water emergency_zone restricted_area].include?(feature_type)
  end
  
  # Calculate feature area (for polygons)
  def area_km2
    return 0 unless polygon_feature? && geometry.present?
    
    coords = geometry.dig('coordinates', 0)
    return 0 unless coords&.length&.> 2
    
    # Simple area calculation using shoelace formula
    area = 0
    (0...coords.length - 1).each do |i|
      j = (i + 1) % (coords.length - 1)
      area += coords[i][0] * coords[j][1]
      area -= coords[j][0] * coords[i][1]
    end
    
    (area.abs / 2.0) * (111.32 ** 2) # Convert degrees to km²
  end
  
  # Calculate feature length (for lines)
  def length_km
    return 0 unless linear_feature? && geometry.present?
    
    coords = geometry['coordinates']
    return 0 unless coords&.length&.> 1
    
    total_length = 0
    (0...coords.length - 1).each do |i|
      total_length += haversine_distance(
        coords[i][1], coords[i][0],
        coords[i + 1][1], coords[i + 1][0]
      )
    end
    
    total_length
  end
  
  # Check if point is within polygon feature
  def contains_point?(lat, lng)
    return false unless polygon_feature? && geometry.present?
    
    coords = geometry.dig('coordinates', 0)
    return false unless coords&.length&.> 2
    
    # Ray casting algorithm
    inside = false
    j = coords.length - 2
    
    (0...coords.length - 1).each do |i|
      if ((coords[i][1] > lat) != (coords[j][1] > lat)) &&
         (lng < (coords[j][0] - coords[i][0]) * (lat - coords[i][1]) / (coords[j][1] - coords[i][1]) + coords[i][0])
        inside = !inside
      end
      j = i
    end
    
    inside
  end
  
  # Convert to GeoJSON
  def to_geojson
    {
      type: 'Feature',
      properties: {
        id: id,
        name: name,
        feature_type: feature_type
      }.merge(properties || {}),
      geometry: geometry || point_geometry
    }
  end
  
  # Get all features as GeoJSON collection
  def self.to_geojson_collection(features = all)
    {
      type: 'FeatureCollection',
      features: features.map(&:to_geojson)
    }
  end
  
  private
  
  def set_defaults
    self.properties ||= {}
  end
  
  def update_center_point
    return unless geometry.present?
    
    case geometry['type']
    when 'Point'
      self.longitude = geometry['coordinates'][0]
      self.latitude = geometry['coordinates'][1]
    when 'LineString'
      coords = geometry['coordinates']
      mid_index = coords.length / 2
      self.longitude = coords[mid_index][0]
      self.latitude = coords[mid_index][1]
    when 'Polygon'
      coords = geometry['coordinates'][0]
      # Calculate centroid
      lat_sum = coords.sum { |coord| coord[1] }
      lng_sum = coords.sum { |coord| coord[0] }
      self.latitude = lat_sum / coords.length
      self.longitude = lng_sum / coords.length
    end
  end
  
  def point_geometry
    return nil unless point_feature? && latitude.present? && longitude.present?
    
    {
      type: 'Point',
      coordinates: [longitude, latitude]
    }
  end
  
  def haversine_distance(lat1, lng1, lat2, lng2)
    rad_per_deg = Math::PI / 180
    rkm = 6371
    
    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlng_rad = (lng2 - lng1) * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg
    
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlng_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rkm * c
  end
end
