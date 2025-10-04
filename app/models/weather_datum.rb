class WeatherDatum < ApplicationRecord
  has_many :dispersion_calculations, dependent: :destroy
  
  validates :temperature, presence: true, numericality: true
  validates :humidity, presence: true, numericality: { in: 0..100 }
  validates :pressure, presence: true, numericality: { greater_than: 0 }
  validates :wind_speed, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :wind_direction, presence: true, numericality: { in: 0..360 }
  validates :recorded_at, presence: true
  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  validates :source, presence: true, inclusion: { in: %w[weather.gov local_station manual api] }
  
  scope :recent, -> { where('recorded_at >= ?', 24.hours.ago) }
  scope :by_location, ->(lat, lon, radius = 0.1) { 
    where(
      'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      lat - radius, lat + radius, lon - radius, lon + radius
    )
  }
  
  def coordinates
    [latitude, longitude]
  end
  
  def wind_vector
    {
      speed: wind_speed,
      direction: wind_direction,
      u_component: -wind_speed * Math.sin(wind_direction * Math::PI / 180),
      v_component: -wind_speed * Math.cos(wind_direction * Math::PI / 180)
    }
  end
  
  # Calculate atmospheric stability class using Turner method
  def stability_class
    # Simplified Turner method based on wind speed and time of day
    hour = recorded_at.hour
    
    if wind_speed < 2
      daytime? ? 'E' : 'F'  # Slightly unstable / Moderately stable
    elsif wind_speed < 3
      daytime? ? 'D' : 'E'  # Neutral / Slightly unstable
    elsif wind_speed < 5
      daytime? ? 'C' : 'D'  # Slightly unstable / Neutral
    elsif wind_speed < 6
      'D'  # Neutral
    else
      'D'  # Neutral for high wind speeds
    end
  end
  
  private
  
  def daytime?
    hour = recorded_at.hour
    hour >= 7 && hour <= 18
  end
end
