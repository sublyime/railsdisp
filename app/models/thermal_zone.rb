# Thermal Zone model for representing iso-heat flux zones and thermal evacuation areas
# Defines spatial zones based on heat flux thresholds and thermal damage levels
class ThermalZone < ApplicationRecord
  belongs_to :thermal_radiation_incident
  
  # Delegate to incident for convenience
  delegate :dispersion_scenario, :chemical, :latitude, :longitude, :incident_type, to: :thermal_radiation_incident
  
  # Validation
  validates :heat_flux_threshold, :max_radius, :zone_area,
            presence: true, numericality: { greater_than: 0 }
  validates :zone_type, inclusion: { 
    in: %w[no_effect discomfort pain injury severe_burn lethality equipment_damage structural_damage] 
  }
  validates :zone_description, presence: true
  validates :zone_area_km2, numericality: { greater_than: 0 }, allow_nil: true
  validates :estimated_population_affected, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes for zone analysis
  scope :by_zone_type, ->(type) { where(zone_type: type) }
  scope :evacuation_required, -> { where(evacuation_required: true) }
  scope :ordered_by_severity, -> { order(heat_flux_threshold: :desc) }
  scope :high_intensity, -> { where('heat_flux_threshold >= ?', 25000) } # ≥25 kW/m²
  scope :populated, -> { where('estimated_population_affected > 0') }
  scope :emergency_response, -> { where(emergency_response_required: true) }
  
  # Zone type classifications with colors for visualization
  ZONE_CLASSIFICATIONS = {
    'safe' => { color: '#00FF00', priority: 0, description: 'Safe area with no thermal effects' },
    'caution' => { color: '#FFFF00', priority: 1, description: 'Caution area with minor thermal effects' },
    'warning' => { color: '#FFA500', priority: 2, description: 'Warning area with significant thermal hazard' },
    'danger' => { color: '#FF4500', priority: 3, description: 'Danger area with high thermal risk' },
    'extreme' => { color: '#FF0000', priority: 4, description: 'Extreme danger with severe thermal effects' },
    'lethal' => { color: '#8B0000', priority: 5, description: 'Potentially lethal thermal exposure' }
  }.freeze
  
  # Emergency response time requirements (minutes)
  RESPONSE_TIMES = {
    'no_effect' => 60,
    'discomfort' => 30,
    'pain' => 15,
    'injury' => 10,
    'severe_burn' => 5,
    'lethality' => 2,
    'equipment_damage' => 20,
    'structural_damage' => 15
  }.freeze
  
  # Calculate zone geometry and thermal properties
  def calculate_zone_geometry!
    # Update basic geometric properties
    self.zone_area = Math::PI * max_radius**2
    self.zone_area_km2 = zone_area / 1_000_000.0
    
    # Calculate perimeter
    self.zone_perimeter = 2 * Math::PI * max_radius
    
    # Generate zone boundary coordinates
    generate_zone_boundary!
    
    # Calculate overlapping zones
    calculate_zone_overlaps!
    
    save!
  end
  
  # Generate detailed thermal impact assessment
  def calculate_thermal_impact!
    # Population exposure assessment
    density_per_km2 = estimate_population_density
    base_population = (zone_area_km2 * density_per_km2).round
    
    # Adjust for time of day and thermal exposure patterns
    time_factor = calculate_time_of_day_factor
    exposure_factor = calculate_thermal_exposure_factor
    
    self.estimated_population_affected = (base_population * time_factor * exposure_factor).round
    
    # Calculate thermal casualties
    casualty_estimates = calculate_thermal_casualties
    
    update!(
      estimated_casualties: casualty_estimates[:total_casualties],
      buildings_at_risk: calculate_buildings_at_risk,
      evacuation_required: heat_flux_threshold >= ThermalRadiationIncident::HEAT_FLUX_THRESHOLDS['pain'],
      emergency_response_required: heat_flux_threshold >= ThermalRadiationIncident::HEAT_FLUX_THRESHOLDS['injury'],
      fire_suppression_required: heat_flux_threshold >= ThermalRadiationIncident::HEAT_FLUX_THRESHOLDS['equipment_damage'],
      medical_response_required: heat_flux_threshold >= ThermalRadiationIncident::HEAT_FLUX_THRESHOLDS['injury']
    )
  end
  
  # Generate thermal evacuation plan for this zone
  def generate_thermal_evacuation_plan
    # Calculate thermal-specific evacuation parameters
    evacuation_timing = calculate_thermal_evacuation_timing
    shelter_requirements = calculate_thermal_shelter_requirements
    medical_requirements = calculate_medical_requirements
    
    plan = {
      zone_info: {
        type: zone_type,
        heat_flux: heat_flux_threshold,
        radius: max_radius,
        population: estimated_population_affected,
        thermal_risk_level: classify_thermal_risk_level
      },
      timing: {
        immediate_evacuation: evacuation_timing[:immediate],
        safe_evacuation_time: evacuation_timing[:safe_time],
        maximum_exposure_time: evacuation_timing[:max_exposure],
        thermal_protection_time: evacuation_timing[:protection_time]
      },
      logistics: {
        evacuation_capacity_needed: estimated_population_affected,
        thermal_protection_required: calculate_thermal_protection_needs,
        medical_triage_needed: estimate_burn_casualties,
        cooling_stations_required: calculate_cooling_station_needs
      },
      resources: {
        evacuation_routes: calculate_thermal_evacuation_routes,
        thermal_shelters: find_thermal_shelters,
        burn_treatment_facilities: find_burn_treatment_facilities,
        fire_suppression_resources: calculate_fire_suppression_needs
      },
      protective_actions: parse_protective_actions,
      medical_response: medical_requirements,
      communication: generate_thermal_emergency_messages
    }
    
    plan
  end
  
  # Calculate thermal protection zones around this zone
  def calculate_thermal_protection_zones
    protection_factors = {
      'no_effect' => 1.1,
      'discomfort' => 1.3,
      'pain' => 1.8,
      'injury' => 2.5,
      'severe_burn' => 3.5,
      'lethality' => 5.0,
      'equipment_damage' => 2.0,
      'structural_damage' => 3.0
    }
    
    protection_factor = protection_factors[zone_type] || 2.0
    protection_radius = max_radius * protection_factor
    
    {
      thermal_shelter_zone: max_radius * 1.2,
      safe_zone: protection_radius,
      emergency_staging_area: protection_radius * 1.3,
      medical_treatment_area: protection_radius * 1.5,
      fire_suppression_staging: protection_radius * 1.1
    }
  end
  
  # Assess thermal vulnerability of different population groups
  def assess_thermal_vulnerability
    vulnerability_matrix = {
      'general_population' => calculate_general_thermal_vulnerability,
      'elderly' => calculate_elderly_thermal_vulnerability,
      'children' => calculate_children_thermal_vulnerability,
      'outdoor_workers' => calculate_worker_thermal_vulnerability,
      'indoor_population' => calculate_indoor_thermal_vulnerability,
      'special_needs' => calculate_special_needs_thermal_vulnerability
    }
    
    vulnerability_matrix
  end
  
  # Calculate thermal economic impact estimates
  def calculate_thermal_economic_impact
    # Thermal-specific damage costs
    thermal_property_damage = calculate_thermal_property_damage
    
    # Medical treatment costs for thermal injuries
    medical_costs = calculate_thermal_medical_costs
    
    # Business interruption from thermal damage
    thermal_business_interruption = calculate_thermal_business_interruption
    
    # Emergency response costs for thermal incidents
    thermal_emergency_response = calculate_thermal_emergency_response_cost
    
    # Equipment replacement due to thermal damage
    thermal_equipment_damage = calculate_thermal_equipment_damage_cost
    
    total_cost = thermal_property_damage + medical_costs + 
                thermal_business_interruption + thermal_emergency_response + 
                thermal_equipment_damage
    
    {
      property_damage: thermal_property_damage,
      medical_costs: medical_costs,
      business_interruption: thermal_business_interruption,
      emergency_response: thermal_emergency_response,
      equipment_damage: thermal_equipment_damage,
      total_thermal_impact: total_cost,
      cost_per_capita: estimated_population_affected > 0 ? total_cost / estimated_population_affected : 0
    }
  end
  
  # Generate thermal zone contour for mapping
  def generate_thermal_zone_contour(num_points: 72)
    contour_points = []
    angle_step = 360.0 / num_points
    
    (0...num_points).each do |i|
      angle = i * angle_step * Math::PI / 180.0
      
      # Account for wind effects on thermal radiation patterns
      wind_factor = calculate_wind_effect_factor(angle)
      effective_radius = max_radius * wind_factor
      
      # Calculate point coordinates
      dx = effective_radius * Math.cos(angle)
      dy = effective_radius * Math.sin(angle)
      
      # Convert to lat/lon
      lat = latitude + (dy / 111320.0)
      lon = longitude + (dx / (111320.0 * Math.cos(latitude * Math::PI / 180.0)))
      
      contour_points << { 
        latitude: lat, 
        longitude: lon, 
        angle: angle * 180.0 / Math::PI,
        wind_factor: wind_factor
      }
    end
    
    contour_points
  end
  
  # Export thermal zone data for GIS
  def to_geojson
    contour = generate_thermal_zone_contour
    coordinates = contour.map { |point| [point[:longitude], point[:latitude]] }
    coordinates << coordinates.first # Close the polygon
    
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [coordinates]
      },
      properties: {
        zone_type: zone_type,
        heat_flux_threshold: heat_flux_threshold,
        heat_flux_kw_per_m2: heat_flux_threshold / 1000.0,
        max_radius: max_radius,
        zone_area: zone_area,
        zone_description: zone_description,
        population_affected: estimated_population_affected,
        evacuation_required: evacuation_required,
        thermal_risk_level: classify_thermal_risk_level,
        response_time_minutes: RESPONSE_TIMES[zone_type],
        incident_type: incident_type
      }
    }
  end
  
  # Check if a point is within this thermal zone
  def contains_point?(lat, lon)
    distance = calculate_distance_from_center(lat, lon)
    
    # Account for wind effects
    angle = calculate_angle_from_center(lat, lon)
    wind_factor = calculate_wind_effect_factor(angle)
    effective_radius = max_radius * wind_factor
    
    distance <= effective_radius
  end
  
  # Calculate distance from zone center
  def calculate_distance_from_center(lat, lon)
    # Haversine distance
    lat1, lon1 = latitude * Math::PI / 180, longitude * Math::PI / 180
    lat2, lon2 = lat * Math::PI / 180, lon * Math::PI / 180
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = Math.sin(dlat/2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    6371000 * c # Distance in meters
  end
  
  # Calculate angle from zone center
  def calculate_angle_from_center(lat, lon)
    lat1, lon1 = latitude * Math::PI / 180, longitude * Math::PI / 180
    lat2, lon2 = lat * Math::PI / 180, lon * Math::PI / 180
    
    dlon = lon2 - lon1
    
    y = Math.sin(dlon) * Math.cos(lat2)
    x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dlon)
    
    angle = Math.atan2(y, x) * 180.0 / Math::PI
    (angle + 360) % 360 # Normalize to 0-360 degrees
  end
  
  # Thermal zone comparison and ranking
  def thermal_risk_score
    # Calculate composite thermal risk score
    heat_flux_score = [Math.log10(heat_flux_threshold / 1000.0) * 20, 50].min # Max 50 points
    population_score = [Math.log10(estimated_population_affected + 1) * 8, 25].min # Max 25 points
    area_score = [Math.log10(zone_area_km2 + 1) * 3, 15].min # Max 15 points
    response_score = evacuation_required ? 10 : 0 # Max 10 points
    
    (heat_flux_score + population_score + area_score + response_score).round(1)
  end
  
  # Calculate thermal dose for zone exposure
  def calculate_zone_thermal_dose(exposure_time = nil)
    exposure_time ||= thermal_radiation_incident.fire_duration || 60.0
    
    # Use threshold heat flux for conservative estimate
    thermal_dose = (heat_flux_threshold ** (4.0/3.0)) * exposure_time
    
    {
      thermal_dose: thermal_dose,
      exposure_time: exposure_time,
      heat_flux: heat_flux_threshold,
      severity_level: assess_thermal_dose_severity(thermal_dose)
    }
  end
  
  # Assess building thermal vulnerability in zone
  def assess_building_thermal_vulnerability
    vulnerability_by_type = {
      'wood_frame' => calculate_wood_frame_thermal_vulnerability,
      'steel_frame' => calculate_steel_frame_thermal_vulnerability,
      'concrete' => calculate_concrete_thermal_vulnerability,
      'masonry' => calculate_masonry_thermal_vulnerability,
      'mobile_home' => calculate_mobile_home_thermal_vulnerability,
      'industrial' => calculate_industrial_thermal_vulnerability
    }
    
    vulnerability_by_type
  end
  
  private
  
  # Estimate population density based on zone location and characteristics
  def estimate_population_density
    # Population density varies by zone type and location
    base_density = case zone_type
                  when 'no_effect', 'discomfort'
                    800 # Lower density outer areas
                  when 'pain'
                    1200 # Moderate density
                  when 'injury', 'severe_burn'
                    1500 # Higher density inner areas
                  else
                    1000 # Default
                  end
    
    # Adjust for thermal incident characteristics
    incident_factor = case incident_type
                     when 'bleve_fireball'
                       0.7 # Industrial area, lower population
                     when 'pool_fire'
                       1.0 # Mixed area
                     when 'jet_fire'
                       0.8 # Industrial/commercial
                     else
                       0.9 # Default
                     end
    
    base_density * incident_factor
  end
  
  def calculate_time_of_day_factor
    # Adjust population based on time of day for thermal incidents
    hour = Time.current.hour
    
    case hour
    when 6..8, 17..19 # Rush hours - higher outdoor exposure
      1.3
    when 9..17 # Business hours - mixed indoor/outdoor
      1.0
    when 22..6 # Night hours - mostly indoor, protected
      0.6
    else
      1.0
    end
  end
  
  def calculate_thermal_exposure_factor
    # Adjust for thermal exposure characteristics
    case zone_type
    when 'no_effect'
      1.0 # Full population considered
    when 'discomfort'
      0.9 # Some may seek shelter
    when 'pain'
      0.7 # Many will seek shelter quickly
    when 'injury', 'severe_burn'
      0.5 # Most will evacuate or shelter
    when 'lethality'
      0.3 # Limited exposure expected
    else
      0.8 # Default
    end
  end
  
  def calculate_thermal_casualties
    return { total_casualties: 0, burn_casualties: 0, heat_stress: 0 } if estimated_population_affected == 0
    
    # Casualty rates based on heat flux level
    casualty_rates = case zone_type
                    when 'no_effect', 'discomfort'
                      { burn_rate: 0.0, heat_stress_rate: 0.01 }
                    when 'pain'
                      { burn_rate: 0.05, heat_stress_rate: 0.15 }
                    when 'injury'
                      { burn_rate: 0.3, heat_stress_rate: 0.5 }
                    when 'severe_burn'
                      { burn_rate: 0.7, heat_stress_rate: 0.8 }
                    when 'lethality'
                      { burn_rate: 0.9, heat_stress_rate: 0.95 }
                    else
                      { burn_rate: 0.1, heat_stress_rate: 0.2 }
                    end
    
    burn_casualties = (estimated_population_affected * casualty_rates[:burn_rate]).round
    heat_stress_casualties = (estimated_population_affected * casualty_rates[:heat_stress_rate]).round
    total_casualties = [burn_casualties + heat_stress_casualties, estimated_population_affected].min
    
    { 
      total_casualties: total_casualties, 
      burn_casualties: burn_casualties, 
      heat_stress: heat_stress_casualties 
    }
  end
  
  def generate_zone_boundary!
    # Generate thermal zone boundary accounting for wind effects
    boundary_points = generate_thermal_zone_contour(num_points: 72)
    
    # Store as JSON for database
    self.zone_boundary_coordinates = boundary_points.to_json
  end
  
  def calculate_zone_overlaps!
    # Find overlapping thermal zones from the same incident
    overlapping_zones = thermal_radiation_incident.thermal_zones
                                                .where.not(id: id)
                                                .where('max_radius + ? >= ABS(max_radius - ?)', max_radius, max_radius)
    
    self.overlapping_zones = overlapping_zones.pluck(:zone_type).to_json
  end
  
  def classify_thermal_risk_level
    case heat_flux_threshold
    when 0...2500
      'low'
    when 2500...5000
      'moderate'
    when 5000...12500
      'high'
    when 12500...25000
      'severe'
    when 25000...37500
      'extreme'
    else
      'lethal'
    end
  end
  
  def calculate_wind_effect_factor(angle)
    # Account for wind effects on thermal radiation patterns
    return 1.0 unless thermal_radiation_incident.wind_speed.present?
    
    wind_speed = thermal_radiation_incident.wind_speed
    return 1.0 if wind_speed < 2.0 # No significant wind effects
    
    wind_direction = thermal_radiation_incident.wind_direction || 0
    relative_angle = (angle * 180.0 / Math::PI - wind_direction).abs
    relative_angle = [relative_angle, 360 - relative_angle].min # Use smaller angle
    
    # Wind effects depend on incident type
    case incident_type
    when 'jet_fire', 'pool_fire'
      # Flame tilt affects radiation pattern
      if relative_angle < 30
        1.0 + (wind_speed / 20.0) # Downwind extension
      elsif relative_angle > 150
        1.0 - (wind_speed / 40.0) # Upwind reduction
      else
        1.0 # Crosswind minimal effect
      end
    when 'bleve_fireball'
      # Minimal wind effects on spherical fireball
      1.0
    else
      1.0
    end
  end
  
  def parse_protective_actions
    if protective_actions.present?
      JSON.parse(protective_actions)
    else
      default_thermal_protective_actions
    end
  rescue JSON::ParserError
    default_thermal_protective_actions
  end
  
  def default_thermal_protective_actions
    case zone_type
    when 'no_effect', 'discomfort'
      ['Monitor thermal conditions', 'Stay hydrated', 'Seek shade if outdoors']
    when 'pain'
      ['Evacuate if possible', 'Seek immediate shelter', 'Cover exposed skin']
    when 'injury', 'severe_burn'
      ['Immediate evacuation required', 'Emergency medical response', 'Fire suppression activation']
    when 'lethality'
      ['Emergency evacuation', 'Medical triage', 'Burn treatment preparation']
    when 'equipment_damage', 'structural_damage'
      ['Industrial evacuation', 'Fire protection systems', 'Equipment cooling']
    else
      ['Monitor situation', 'Follow thermal emergency instructions']
    end
  end
  
  # Thermal evacuation timing calculations
  def calculate_thermal_evacuation_timing
    fire_duration = thermal_radiation_incident.fire_duration || 300.0
    
    # Time limits based on thermal exposure
    safe_exposure_times = {
      'no_effect' => Float::INFINITY,
      'discomfort' => 3600, # 1 hour
      'pain' => 300, # 5 minutes
      'injury' => 60, # 1 minute
      'severe_burn' => 15, # 15 seconds
      'lethality' => 5 # 5 seconds
    }
    
    max_exposure = safe_exposure_times[zone_type] || 60.0
    safe_evacuation_time = [max_exposure * 0.5, fire_duration * 0.8].min
    
    {
      immediate: zone_type.in?(['severe_burn', 'lethality']),
      safe_time: safe_evacuation_time,
      max_exposure: max_exposure,
      protection_time: max_exposure * 0.3 # Time to apply protection
    }
  end
  
  # Thermal vulnerability calculations for different population groups
  def calculate_general_thermal_vulnerability
    base_vulnerability = case zone_type
                        when 'no_effect', 'discomfort' then 0.1
                        when 'pain' then 0.3
                        when 'injury' then 0.6
                        when 'severe_burn' then 0.8
                        when 'lethality' then 0.95
                        else 0.4
                        end
    
    base_vulnerability
  end
  
  def calculate_elderly_thermal_vulnerability
    calculate_general_thermal_vulnerability * 1.5 # 50% higher vulnerability
  end
  
  def calculate_children_thermal_vulnerability
    calculate_general_thermal_vulnerability * 1.3 # 30% higher vulnerability
  end
  
  def calculate_worker_thermal_vulnerability
    outdoor_factor = case zone_type
                    when 'no_effect', 'discomfort' then 1.2 # Higher outdoor exposure
                    else 1.0
                    end
    
    calculate_general_thermal_vulnerability * outdoor_factor
  end
  
  def calculate_indoor_thermal_vulnerability
    # Indoor provides some protection
    protection_factor = case zone_type
                       when 'no_effect', 'discomfort' then 0.5
                       when 'pain' then 0.7
                       when 'injury' then 0.8
                       else 0.9 # High heat flux penetrates buildings
                       end
    
    calculate_general_thermal_vulnerability * protection_factor
  end
  
  def calculate_special_needs_thermal_vulnerability
    calculate_general_thermal_vulnerability * 2.0 # Double vulnerability
  end
  
  # Economic impact calculations
  def calculate_thermal_property_damage
    # Property damage from thermal radiation
    avg_property_value = 250_000 # USD per property
    properties_per_km2 = 50
    total_properties = (zone_area_km2 * properties_per_km2).round
    
    damage_fraction = case zone_type
                     when 'no_effect', 'discomfort' then 0.0
                     when 'pain' then 0.05
                     when 'injury' then 0.2
                     when 'severe_burn' then 0.5
                     when 'lethality' then 0.8
                     when 'equipment_damage' then 0.6
                     when 'structural_damage' then 0.9
                     else 0.3
                     end
    
    total_properties * avg_property_value * damage_fraction
  end
  
  def calculate_thermal_medical_costs
    # Medical costs for thermal injuries
    casualty_estimates = calculate_thermal_casualties
    
    burn_treatment_cost = 150_000 # USD per severe burn case
    heat_stress_treatment = 5_000 # USD per heat stress case
    
    (casualty_estimates[:burn_casualties] * burn_treatment_cost) + 
    (casualty_estimates[:heat_stress] * heat_stress_treatment)
  end
  
  def calculate_thermal_business_interruption
    # Business interruption from thermal effects
    daily_economic_activity = estimated_population_affected * 300 # USD per person per day
    interruption_days = case zone_type
                       when 'no_effect', 'discomfort' then 0
                       when 'pain' then 1
                       when 'injury' then 3
                       when 'severe_burn' then 7
                       when 'lethality' then 14
                       when 'equipment_damage', 'structural_damage' then 21
                       else 2
                       end
    
    daily_economic_activity * interruption_days
  end
  
  def calculate_thermal_emergency_response_cost
    # Emergency response costs for thermal incidents
    base_cost = 100_000 # Base response cost
    population_factor = estimated_population_affected * 20
    severity_factor = case zone_type
                     when 'no_effect', 'discomfort' then 1.0
                     when 'pain' then 1.5
                     when 'injury' then 2.0
                     when 'severe_burn' then 3.0
                     when 'lethality' then 5.0
                     else 2.5
                     end
    
    (base_cost + population_factor) * severity_factor
  end
  
  def calculate_thermal_equipment_damage_cost
    # Equipment damage from thermal radiation
    equipment_density = case zone_type
                       when 'equipment_damage', 'structural_damage' then 500_000 # High-value equipment
                       else 50_000 # General equipment
                       end
    
    area_factor = zone_area_km2
    damage_probability = case zone_type
                        when 'equipment_damage' then 0.7
                        when 'structural_damage' then 0.9
                        when 'lethality' then 0.5
                        else 0.1
                        end
    
    equipment_density * area_factor * damage_probability
  end
  
  # Helper methods for evacuation planning
  def calculate_thermal_protection_needs
    # Calculate thermal protection equipment needed
    protection_needed = case zone_type
                       when 'pain' then estimated_population_affected * 0.8
                       when 'injury', 'severe_burn' then estimated_population_affected * 1.0
                       else 0
                       end
    
    {
      thermal_blankets: protection_needed,
      cooling_supplies: protection_needed * 0.5,
      burn_kits: protection_needed * 0.3
    }
  end
  
  def estimate_burn_casualties
    calculate_thermal_casualties[:burn_casualties]
  end
  
  def calculate_cooling_station_needs
    # Number of cooling stations needed
    [(estimated_population_affected / 100.0).ceil, 1].max
  end
  
  def calculate_thermal_evacuation_routes
    # Thermal-specific evacuation routes (away from heat source)
    [
      { route_id: 'thermal_north', direction: 0, thermal_protection: 'high' },
      { route_id: 'thermal_east', direction: 90, thermal_protection: 'medium' },
      { route_id: 'thermal_south', direction: 180, thermal_protection: 'high' },
      { route_id: 'thermal_west', direction: 270, thermal_protection: 'medium' }
    ]
  end
  
  def find_thermal_shelters
    # Thermal protection shelters
    num_shelters = [(estimated_population_affected / 200.0).ceil, 1].max
    
    (1..num_shelters).map do |i|
      {
        id: "thermal_shelter_#{i}",
        capacity: 200,
        distance_km: max_radius / 1000.0 + (i * 1.5),
        thermal_protection_rating: 'high'
      }
    end
  end
  
  def find_burn_treatment_facilities
    # Medical facilities with burn treatment capability
    [
      { name: 'Regional Burn Center', distance_km: max_radius / 1000.0 + 10, burn_beds: 50 },
      { name: 'Emergency Hospital', distance_km: max_radius / 1000.0 + 5, burn_beds: 20 }
    ]
  end
  
  def calculate_fire_suppression_needs
    {
      fire_departments: [(estimated_population_affected / 3000.0).ceil, 1].max,
      thermal_protection_teams: zone_type.in?(['equipment_damage', 'structural_damage']) ? 3 : 1,
      cooling_water_capacity: zone_area_km2 * 100000 # Liters
    }
  end
  
  def generate_thermal_emergency_messages
    {
      immediate: "THERMAL HAZARD: #{zone_type.humanize} zone. Heat flux: #{(heat_flux_threshold/1000.0).round(1)} kW/m². #{evacuation_required? ? 'EVACUATE IMMEDIATELY' : 'Seek thermal protection'}",
      detailed: "Thermal radiation zone with #{heat_flux_threshold} W/m² heat flux. #{zone_description}",
      actions: parse_protective_actions.join('. ')
    }
  end
  
  def assess_thermal_dose_severity(thermal_dose)
    case thermal_dose
    when 0...1000
      'minimal'
    when 1000...5000
      'moderate'
    when 5000...15000
      'severe'
    when 15000...50000
      'critical'
    else
      'extreme'
    end
  end
  
  # Building thermal vulnerability calculations
  def calculate_wood_frame_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...5 then 0.1
    when 5...15 then 0.4
    when 15...30 then 0.8
    else 0.95
    end
  end
  
  def calculate_steel_frame_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...10 then 0.05
    when 10...25 then 0.3
    when 25...50 then 0.7
    else 0.9
    end
  end
  
  def calculate_concrete_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...15 then 0.02
    when 15...35 then 0.2
    when 35...70 then 0.6
    else 0.85
    end
  end
  
  def calculate_masonry_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...8 then 0.08
    when 8...20 then 0.35
    when 20...40 then 0.75
    else 0.92
    end
  end
  
  def calculate_mobile_home_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...3 then 0.2
    when 3...10 then 0.6
    when 10...20 then 0.9
    else 0.98
    end
  end
  
  def calculate_industrial_thermal_vulnerability
    heat_flux_kw = heat_flux_threshold / 1000.0
    
    case heat_flux_kw
    when 0...20 then 0.05
    when 20...50 then 0.3
    when 50...100 then 0.7
    else 0.95
    end
  end
  
  def calculate_buildings_at_risk
    # Estimate buildings in thermal zone
    (zone_area_km2 * 50).round # Assume 50 buildings per km²
  end
end