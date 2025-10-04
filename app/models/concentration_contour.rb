# Concentration contours representing iso-concentration lines and impact zones
# Stores contour geometry, toxicological significance, and population impact estimates
class ConcentrationContour < ApplicationRecord
  belongs_to :atmospheric_dispersion
  
  # Validations
  validates :concentration_level, presence: true, numericality: { greater_than: 0 }
  validates :time_step, presence: true, numericality: { greater_than: 0 }
  validates :elapsed_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :concentration_units, inclusion: { in: %w[mg/m3 ppm ug/m3 g/m3] }
  validates :contour_type, inclusion: { 
    in: %w[aegl_1 aegl_2 aegl_3 erpg_1 erpg_2 erpg_3 pac_1 pac_2 pac_3 idlh custom flammable explosive] 
  }
  
  # Scopes for filtering and analysis
  scope :at_time_step, ->(step) { where(time_step: step) }
  scope :at_elapsed_time, ->(time) { where(elapsed_time: time) }
  scope :by_contour_type, ->(type) { where(contour_type: type) }
  scope :by_concentration_range, ->(min, max) { where(concentration_level: min..max) }
  scope :converged, -> { where(calculation_converged: true) }
  scope :with_population_impact, -> { where('estimated_population_affected > 0') }
  scope :significant_area, -> { where('contour_area > 1000') } # >1000 m²
  
  # Delegate to atmospheric dispersion and scenario
  delegate :dispersion_scenario, to: :atmospheric_dispersion
  delegate :chemical, to: :atmospheric_dispersion
  delegate :pasquill_stability_class, to: :atmospheric_dispersion
  
  # Contour geometry parsing and analysis
  def contour_coordinates
    return [] unless contour_geometry.present?
    
    begin
      case contour_geometry
      when /^POLYGON/
        parse_wkt_polygon
      when /^\{.*\}$/
        parse_geojson_polygon
      else
        parse_coordinate_pairs
      end
    rescue JSON::ParserError, StandardError => e
      Rails.logger.warn("Failed to parse contour geometry: #{e.message}")
      []
    end
  end
  
  # Convert contour to GeoJSON format
  def to_geojson
    coordinates = contour_coordinates
    return nil if coordinates.empty?
    
    {
      type: "Feature",
      properties: {
        concentration_level: concentration_level,
        concentration_units: concentration_units,
        contour_type: contour_type,
        exposure_duration: exposure_duration,
        time_step: time_step,
        elapsed_time: elapsed_time,
        area_m2: contour_area,
        area_km2: affected_area_km2,
        population_affected: estimated_population_affected,
        max_downwind_extent: max_downwind_extent,
        max_crosswind_extent: max_crosswind_extent
      },
      geometry: {
        type: "Polygon",
        coordinates: [coordinates.map { |coord| [coord[:lon], coord[:lat]] }]
      }
    }
  end
  
  # Toxicological significance analysis
  def toxicological_significance
    return {} unless chemical.toxicological_data
    
    tox_data = chemical.toxicological_data
    duration_minutes = exposure_duration || 60.0
    
    # Determine which guidelines apply for this duration
    guidelines = {}
    
    # AEGL values
    if duration_minutes <= 10
      guidelines[:aegl_1] = tox_data.aegl_1_10min
      guidelines[:aegl_2] = tox_data.aegl_2_10min
      guidelines[:aegl_3] = tox_data.aegl_3_10min
    elsif duration_minutes <= 30
      guidelines[:aegl_1] = tox_data.aegl_1_30min
      guidelines[:aegl_2] = tox_data.aegl_2_30min
      guidelines[:aegl_3] = tox_data.aegl_3_30min
    elsif duration_minutes <= 60
      guidelines[:aegl_1] = tox_data.aegl_1_1hr
      guidelines[:aegl_2] = tox_data.aegl_2_1hr
      guidelines[:aegl_3] = tox_data.aegl_3_1hr
    elsif duration_minutes <= 240
      guidelines[:aegl_1] = tox_data.aegl_1_4hr
      guidelines[:aegl_2] = tox_data.aegl_2_4hr
      guidelines[:aegl_3] = tox_data.aegl_3_4hr
    else
      guidelines[:aegl_1] = tox_data.aegl_1_8hr
      guidelines[:aegl_2] = tox_data.aegl_2_8hr
      guidelines[:aegl_3] = tox_data.aegl_3_8hr
    end
    
    # ERPG values (1-hour exposure)
    guidelines[:erpg_1] = tox_data.erpg_1
    guidelines[:erpg_2] = tox_data.erpg_2
    guidelines[:erpg_3] = tox_data.erpg_3
    
    # Calculate fraction of guidelines
    conc_mg_m3 = concentration_in_mg_m3
    fractions = {}
    
    guidelines.each do |guideline, value|
      next unless value && value > 0
      fractions[guideline] = conc_mg_m3 / value
    end
    
    {
      guidelines_mg_m3: guidelines,
      concentration_fractions: fractions,
      exceeds_aegl_1: fractions[:aegl_1] && fractions[:aegl_1] >= 1.0,
      exceeds_aegl_2: fractions[:aegl_2] && fractions[:aegl_2] >= 1.0,
      exceeds_aegl_3: fractions[:aegl_3] && fractions[:aegl_3] >= 1.0,
      exceeds_erpg_1: fractions[:erpg_1] && fractions[:erpg_1] >= 1.0,
      exceeds_erpg_2: fractions[:erpg_2] && fractions[:erpg_2] >= 1.0,
      exceeds_erpg_3: fractions[:erpg_3] && fractions[:erpg_3] >= 1.0,
      health_impact_summary: determine_health_impact_level(fractions)
    }
  end
  
  # Population impact analysis
  def population_impact_analysis
    {
      total_affected: estimated_population_affected || 0,
      area_affected_km2: affected_area_km2 || 0,
      population_density: calculate_population_density,
      impact_zones: parse_impact_zones,
      vulnerability_assessment: assess_population_vulnerability
    }
  end
  
  # Spatial analysis methods
  def contour_bounds
    coords = contour_coordinates
    return {} if coords.empty?
    
    lats = coords.map { |c| c[:lat] }
    lons = coords.map { |c| c[:lon] }
    
    {
      north: lats.max,
      south: lats.min,
      east: lons.max,
      west: lons.min,
      center_lat: lats.sum / lats.length,
      center_lon: lons.sum / lons.length
    }
  end
  
  def contour_centroid
    bounds = contour_bounds
    return nil if bounds.empty?
    
    {
      latitude: bounds[:center_lat],
      longitude: bounds[:center_lon]
    }
  end
  
  # Check if a point is inside the contour
  def contains_point?(latitude, longitude)
    coords = contour_coordinates
    return false if coords.empty?
    
    # Ray casting algorithm for point-in-polygon
    x, y = longitude, latitude
    inside = false
    
    j = coords.length - 1
    (0...coords.length).each do |i|
      xi, yi = coords[i][:lon], coords[i][:lat]
      xj, yj = coords[j][:lon], coords[j][:lat]
      
      if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        inside = !inside
      end
      
      j = i
    end
    
    inside
  end
  
  # Distance calculations
  def distance_from_source
    centroid = contour_centroid
    return nil unless centroid
    
    source_lat = dispersion_scenario.latitude
    source_lon = dispersion_scenario.longitude
    
    calculate_distance(source_lat, source_lon, centroid[:latitude], centroid[:longitude])
  end
  
  def max_distance_from_source
    coords = contour_coordinates
    return nil if coords.empty?
    
    source_lat = dispersion_scenario.latitude
    source_lon = dispersion_scenario.longitude
    
    coords.map do |coord|
      calculate_distance(source_lat, source_lon, coord[:lat], coord[:lon])
    end.max
  end
  
  # Concentration unit conversions
  def concentration_in_mg_m3
    return concentration_level if concentration_units == 'mg/m3'
    
    case concentration_units
    when 'ppm'
      # Convert ppm to mg/m3 using molecular weight
      mol_weight = chemical.molecular_weight
      return nil unless mol_weight && mol_weight > 0
      
      # At STP: mg/m3 = ppm * MW / 24.45
      concentration_level * mol_weight / 24.45
    when 'ug/m3'
      concentration_level / 1000.0
    when 'g/m3'
      concentration_level * 1000.0
    else
      concentration_level
    end
  end
  
  def concentration_in_ppm
    return concentration_level if concentration_units == 'ppm'
    
    mol_weight = chemical.molecular_weight
    return nil unless mol_weight && mol_weight > 0
    
    case concentration_units
    when 'mg/m3'
      concentration_level * 24.45 / mol_weight
    when 'ug/m3'
      (concentration_level / 1000.0) * 24.45 / mol_weight
    when 'g/m3'
      (concentration_level * 1000.0) * 24.45 / mol_weight
    else
      nil
    end
  end
  
  # Time series analysis
  def temporal_evolution
    # Get all contours for the same concentration level and type
    similar_contours = ConcentrationContour
      .where(atmospheric_dispersion: atmospheric_dispersion)
      .where(concentration_level: concentration_level)
      .where(contour_type: contour_type)
      .order(:elapsed_time)
    
    similar_contours.map do |contour|
      {
        time_step: contour.time_step,
        elapsed_time: contour.elapsed_time,
        area: contour.contour_area,
        max_extent: contour.max_downwind_extent,
        population_affected: contour.estimated_population_affected
      }
    end
  end
  
  # Data export for visualization
  def to_visualization_hash
    {
      id: id,
      concentration: {
        level: concentration_level,
        units: concentration_units,
        mg_m3: concentration_in_mg_m3,
        ppm: concentration_in_ppm,
        type: contour_type
      },
      geometry: {
        coordinates: contour_coordinates,
        geojson: to_geojson,
        area_m2: contour_area,
        area_km2: affected_area_km2,
        max_downwind: max_downwind_extent,
        max_crosswind: max_crosswind_extent
      },
      time: {
        step: time_step,
        elapsed: elapsed_time,
        exposure_duration: exposure_duration
      },
      impact: {
        population_affected: estimated_population_affected,
        impact_zones: parse_impact_zones,
        toxicological: toxicological_significance
      },
      quality: {
        converged: calculation_converged,
        accuracy: calculation_accuracy,
        notes: calculation_notes
      }
    }
  end
  
  private
  
  def parse_wkt_polygon
    # Parse WKT POLYGON format
    coords_string = contour_geometry.match(/POLYGON\(\((.+)\)\)/)[1]
    coords_string.split(',').map do |pair|
      lon, lat = pair.strip.split(' ').map(&:to_f)
      { lat: lat, lon: lon }
    end
  rescue
    []
  end
  
  def parse_geojson_polygon
    # Parse GeoJSON polygon
    data = JSON.parse(contour_geometry)
    coords = data.dig('geometry', 'coordinates', 0) || data['coordinates'] || []
    
    coords.map do |coord|
      { lat: coord[1], lon: coord[0] }
    end
  rescue
    []
  end
  
  def parse_coordinate_pairs
    # Parse simple coordinate pairs format: "lat1,lon1;lat2,lon2;..."
    contour_geometry.split(';').map do |pair|
      lat, lon = pair.split(',').map(&:to_f)
      { lat: lat, lon: lon }
    end
  rescue
    []
  end
  
  def determine_health_impact_level(fractions)
    if fractions[:aegl_3] && fractions[:aegl_3] >= 1.0 || fractions[:erpg_3] && fractions[:erpg_3] >= 1.0
      'life_threatening'
    elsif fractions[:aegl_2] && fractions[:aegl_2] >= 1.0 || fractions[:erpg_2] && fractions[:erpg_2] >= 1.0
      'disabling'
    elsif fractions[:aegl_1] && fractions[:aegl_1] >= 1.0 || fractions[:erpg_1] && fractions[:erpg_1] >= 1.0
      'notable'
    elsif fractions.values.any? { |f| f && f > 0.1 }
      'mild'
    else
      'minimal'
    end
  end
  
  def calculate_population_density
    return 0 if contour_area.nil? || contour_area == 0 || estimated_population_affected.nil?
    
    estimated_population_affected / (contour_area / 1_000_000.0) # people per km²
  end
  
  def parse_impact_zones
    return [] unless impact_zones.present?
    
    begin
      JSON.parse(impact_zones)
    rescue JSON::ParserError
      []
    end
  end
  
  def assess_population_vulnerability
    # Placeholder for vulnerability assessment based on demographics, building types, etc.
    {
      vulnerable_populations: 'unknown',
      building_density: 'unknown',
      evacuation_difficulty: 'unknown',
      emergency_services_access: 'unknown'
    }
  end
  
  def calculate_distance(lat1, lon1, lat2, lon2)
    # Haversine formula for distance calculation
    r = 6371000 # Earth radius in meters
    
    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180
    
    a = Math.sin(delta_lat / 2)**2 + 
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lon / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    r * c
  end
end