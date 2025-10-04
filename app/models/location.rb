class Location < ApplicationRecord
  has_many :dispersion_events, dependent: :destroy
  
  validates :name, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  validates :elevation, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :building_height, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :terrain_type, inclusion: { in: %w[urban suburban rural industrial residential commercial] }, allow_nil: true
  validates :building_type, inclusion: { in: %w[none low_rise mid_rise high_rise industrial warehouse] }, allow_nil: true
  
  scope :with_buildings, -> { where.not(building_height: nil) }
  scope :by_terrain, ->(type) { where(terrain_type: type) }
  
  def coordinates
    [latitude, longitude]
  end
  
  def has_buildings?
    building_height.present? && building_height > 0
  end
  
  # Calculate surface roughness for dispersion modeling
  def surface_roughness
    case terrain_type
    when 'urban'
      1.0 + (building_height.to_f / 10.0)
    when 'suburban'
      0.5 + (building_height.to_f / 20.0)
    when 'industrial'
      0.8 + (building_height.to_f / 15.0)
    when 'rural'
      0.1
    else
      0.3
    end
  end
end
