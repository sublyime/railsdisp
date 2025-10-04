# Weather Helper methods for view rendering

module WeatherHelper
  # Color coding for temperature badges
  def temperature_color(temp)
    case temp
    when -Float::INFINITY..-10
      'primary'     # Very cold - blue
    when -10..0
      'info'        # Cold - light blue  
    when 0..15
      'secondary'   # Cool - gray
    when 15..25
      'success'     # Comfortable - green
    when 25..35
      'warning'     # Warm - yellow
    else
      'danger'      # Hot - red
    end
  end

  # Convert wind direction degrees to compass text
  def wind_direction_text(degrees)
    directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW']
    index = ((degrees + 11.25) / 22.5).to_i % 16
    directions[index]
  end

  # Get human-readable stability class description
  def stability_description(stability_class)
    descriptions = {
      'A' => 'Very unstable',
      'B' => 'Moderately unstable', 
      'C' => 'Slightly unstable',
      'D' => 'Neutral',
      'E' => 'Slightly stable',
      'F' => 'Moderately stable',
      'G' => 'Very stable'
    }
    descriptions[stability_class] || 'Unknown'
  end

  # Format wind speed with appropriate units and color
  def wind_speed_badge(wind_speed)
    color = case wind_speed
            when 0..2
              'secondary'
            when 2..5
              'success'
            when 5..10
              'warning'
            when 10..15
              'danger'
            else
              'dark'
            end
    
    content_tag(:span, "#{wind_speed} m/s", class: "badge bg-#{color}")
  end

  # Format humidity with color indication
  def humidity_indicator(humidity)
    color = case humidity
            when 0..30
              'warning'     # Low humidity
            when 30..70
              'success'     # Normal
            else
              'info'        # High humidity
            end
    
    content_tag(:span, "#{humidity}%", class: "text-#{color}")
  end

  # Format pressure with trend indication if available
  def pressure_display(pressure, previous_pressure = nil)
    trend = ''
    if previous_pressure
      diff = pressure - previous_pressure
      if diff.abs > 1
        trend = diff > 0 ? ' ↗' : ' ↘'
      end
    end
    
    "#{pressure} hPa#{trend}"
  end

  # Weather condition icon based on multiple factors
  def weather_icon(weather_data)
    temp = weather_data.temperature
    wind = weather_data.wind_speed
    humidity = weather_data.humidity
    cloud_cover = weather_data.cloud_cover || 50
    
    # Determine primary icon
    icon = if weather_data.precipitation > 0
             'fas fa-cloud-rain'
           elsif cloud_cover > 80
             'fas fa-cloud'
           elsif cloud_cover > 50
             'fas fa-cloud-sun'
           else
             'fas fa-sun'
           end
    
    # Add modifiers for extreme conditions
    if wind > 15
      icon = 'fas fa-wind'
    elsif temp < -10
      icon = 'fas fa-snowflake'
    elsif temp > 35
      icon = 'fas fa-thermometer-full'
    end
    
    content_tag(:i, '', class: icon)
  end

  # Format visibility with appropriate color
  def visibility_display(visibility)
    color = case visibility
            when 0..1
              'danger'
            when 1..5
              'warning'
            when 5..10
              'success'
            else
              'primary'
            end
    
    content_tag(:span, "#{visibility} km", class: "text-#{color}")
  end

  # Calculate air quality index based on weather conditions
  def air_quality_estimate(weather_data)
    # Simplified AQI estimation based on weather
    score = 100 # Start with good
    
    # Reduce score for conditions that trap pollutants
    score -= 20 if weather_data.wind_speed < 2  # Low wind
    score -= 15 if weather_data.stability_class.in?(['E', 'F', 'G'])  # Stable conditions
    score -= 10 if weather_data.humidity > 85   # High humidity
    
    # Improve score for dispersive conditions
    score += 10 if weather_data.wind_speed > 8  # Strong wind
    score += 15 if weather_data.stability_class.in?(['A', 'B'])  # Unstable conditions
    
    score = [[score, 0].max, 500].min  # Clamp between 0-500
    
    case score
    when 0..50
      { level: 'Good', color: 'success', score: score }
    when 51..100
      { level: 'Moderate', color: 'warning', score: score }
    when 101..150
      { level: 'Poor', color: 'danger', score: score }
    else
      { level: 'Very Poor', color: 'dark', score: score }
    end
  end

  # Format coordinates for display
  def format_coordinates(lat, lon)
    lat_dir = lat >= 0 ? 'N' : 'S'
    lon_dir = lon >= 0 ? 'E' : 'W'
    
    "#{lat.abs.round(4)}°#{lat_dir}, #{lon.abs.round(4)}°#{lon_dir}"
  end

  # Time until next weather update
  def next_update_time
    last_update = WeatherDatum.maximum(:recorded_at) || 30.minutes.ago
    next_update = last_update + 30.seconds
    
    if next_update > Time.current
      time_ago_in_words(next_update)
    else
      'Due now'
    end
  end

  # Weather trend analysis
  def weather_trend(location_lat, location_lon, hours = 6)
    weather_data = WeatherDatum.by_location(location_lat, location_lon)
                               .where('recorded_at >= ?', hours.hours.ago)
                               .order(:recorded_at)
    
    return {} if weather_data.count < 2
    
    first = weather_data.first
    last = weather_data.last
    
    {
      temperature_trend: trend_direction(last.temperature, first.temperature),
      pressure_trend: trend_direction(last.pressure, first.pressure),
      wind_trend: trend_direction(last.wind_speed, first.wind_speed),
      stability_trend: stability_trend_direction(last.stability_class, first.stability_class)
    }
  end

  private

  def trend_direction(current, previous)
    diff = current - previous
    return 'stable' if diff.abs < 0.1
    diff > 0 ? 'rising' : 'falling'
  end

  def stability_trend_direction(current, previous)
    stability_order = %w[A B C D E F G]
    current_index = stability_order.index(current) || 3
    previous_index = stability_order.index(previous) || 3
    
    if current_index == previous_index
      'stable'
    elsif current_index > previous_index
      'more_stable'
    else
      'less_stable'
    end
  end
end