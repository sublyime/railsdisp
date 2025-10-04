class MapLayer < ApplicationRecord
  # Associations
  has_many :buildings, dependent: :destroy
  has_many :terrain_points, dependent: :destroy
  has_many :gis_features, dependent: :destroy
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :layer_type, presence: true, inclusion: { 
    in: %w[base terrain buildings infrastructure boundaries weather overlay]
  }
  validates :z_index, presence: true, numericality: { only_integer: true }
  
  # Callbacks
  before_validation :set_defaults
  
  # Scopes
  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:z_index, :name) }
  scope :by_type, ->(type) { where(layer_type: type) }
  
  # JSON serialization for style configuration
  serialize :style_config, coder: JSON
  
  def style_config
    super || default_style_config
  end
  
  def feature_count
    buildings.count + terrain_points.count + gis_features.count
  end
  
  def bounds
    # Calculate layer bounds from all features
    all_features = []
    all_features += buildings.pluck(:latitude, :longitude)
    all_features += terrain_points.pluck(:latitude, :longitude)
    all_features += gis_features.pluck(:latitude, :longitude)
    
    return nil if all_features.empty?
    
    lats = all_features.map(&:first).compact
    lngs = all_features.map(&:last).compact
    
    {
      north: lats.max,
      south: lats.min,
      east: lngs.max,
      west: lngs.min
    }
  end
  
  private
  
  def set_defaults
    self.visible = true if visible.nil?
    self.z_index ||= 0
  end
  
  def default_style_config
    case layer_type
    when 'buildings'
      {
        fillColor: '#ff6b6b',
        fillOpacity: 0.7,
        color: '#c92a2a',
        weight: 2
      }
    when 'terrain'
      {
        fillColor: '#51cf66',
        fillOpacity: 0.4,
        color: '#37b24d',
        weight: 1
      }
    when 'infrastructure'
      {
        fillColor: '#339af0',
        fillOpacity: 0.6,
        color: '#1971c2',
        weight: 2
      }
    else
      {
        fillColor: '#868e96',
        fillOpacity: 0.5,
        color: '#495057',
        weight: 1
      }
    end
  end
end
