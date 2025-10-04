# Explosion Zone model for representing damage zones and evacuation areas
# Defines spatial zones based on overpressure thresholds and damage levels
class ExplosionZone < ApplicationRecord
  belongs_to :vapor_cloud_explosion
  
  # Delegate to explosion for convenience
  delegate :dispersion_scenario, :chemical, :latitude, :longitude, to: :vapor_cloud_explosion
  
  # Validation
  validates :overpressure_threshold, :max_radius, :zone_area,
            presence: true, numericality: { greater_than: 0 }
  validates :zone_type, inclusion: { 
    in: %w[window_breakage structural_damage building_collapse fatality_threshold total_destruction
           evacuation_zone shelter_zone exclusion_zone emergency_response] 
  }
  validates :damage_description, presence: true
  validates :zone_area_km2, numericality: { greater_than: 0 }, allow_nil: true
  validates :estimated_population_affected, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # Scopes for zone analysis
  scope :by_zone_type, ->(type) { where(zone_type: type) }
  scope :evacuation_required, -> { where(evacuation_required: true) }
  scope :ordered_by_severity, -> { order(:overpressure_threshold) }
  scope :high_risk, -> { where('overpressure_threshold >= ?', 20000) } # ≥20 kPa
  scope :populated, -> { where('estimated_population_affected > 0') }
  
  # Zone type classifications
  ZONE_CLASSIFICATIONS = {
    'safe' => { color: '#00FF00', priority: 0, description: 'Safe area with minimal risk' },
    'caution' => { color: '#FFFF00', priority: 1, description: 'Caution area with minor damage potential' },
    'danger' => { color: '#FFA500', priority: 2, description: 'Danger area with significant damage potential' },
    'extreme' => { color: '#FF0000', priority: 3, description: 'Extreme danger with high fatality risk' },
    'exclusion' => { color: '#800080', priority: 4, description: 'Total exclusion zone' }
  }.freeze
  
  # Emergency response time requirements (minutes)
  RESPONSE_TIMES = {
    'window_breakage' => 30,
    'structural_damage' => 15,
    'building_collapse' => 10,
    'fatality_threshold' => 5,
    'total_destruction' => 2
  }.freeze
  
  # Calculate zone geometry and properties
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
  
  # Generate detailed population impact assessment
  def calculate_population_impact!
    # This would integrate with census or demographic data
    # For now, use simplified density estimates
    
    density_per_km2 = estimate_population_density
    base_population = (zone_area_km2 * density_per_km2).round
    
    # Adjust for time of day and building occupancy
    time_factor = calculate_time_of_day_factor
    occupancy_factor = calculate_occupancy_factor
    
    self.estimated_population_affected = (base_population * time_factor * occupancy_factor).round
    
    # Calculate casualties based on damage level
    casualty_estimates = calculate_casualty_estimates
    
    update!(
      estimated_fatalities: casualty_estimates[:fatalities],
      estimated_injuries: casualty_estimates[:injuries],
      buildings_at_risk: calculate_buildings_at_risk,
      critical_infrastructure_affected: assess_critical_infrastructure
    )
  end
  
  # Generate evacuation plan for this zone
  def generate_evacuation_plan
    # Calculate evacuation parameters
    evacuation_time = calculate_evacuation_time
    shelter_locations = find_shelter_locations
    evacuation_routes = calculate_evacuation_routes
    
    plan = {
      zone_info: {
        type: zone_type,
        radius: max_radius,
        population: estimated_population_affected,
        risk_level: classify_risk_level
      },
      timing: {
        evacuation_time_needed: evacuation_time[:total_time],
        warning_time: evacuation_time[:warning_time],
        movement_time: evacuation_time[:movement_time],
        clearance_time: evacuation_time[:clearance_time]
      },
      logistics: {
        evacuation_capacity_needed: estimated_population_affected,
        transportation_required: calculate_transportation_needs,
        special_needs_population: estimate_special_needs_population,
        pet_accommodation: (estimated_population_affected * 0.3).round
      },
      resources: {
        shelter_locations: shelter_locations,
        evacuation_routes: evacuation_routes,
        medical_facilities: find_medical_facilities,
        emergency_services: calculate_emergency_response_needs
      },
      protective_actions: parse_protective_actions,
      communication: generate_public_messages
    }
    
    plan
  end
  
  # Calculate buffer zones around this zone
  def calculate_buffer_zones
    safety_factors = {
      'window_breakage' => 1.2,
      'structural_damage' => 1.5,
      'building_collapse' => 2.0,
      'fatality_threshold' => 2.5,
      'total_destruction' => 3.0
    }
    
    safety_factor = safety_factors[zone_type] || 1.5
    buffer_radius = max_radius * safety_factor
    
    {
      inner_buffer: max_radius * 1.1,
      safety_buffer: buffer_radius,
      emergency_buffer: buffer_radius * 1.2,
      uncertainty_buffer: buffer_radius * 1.5
    }
  end
  
  # Assess vulnerability of different structure types
  def assess_structural_vulnerability
    vulnerability_matrix = {
      'residential' => {
        'wood_frame' => calculate_wood_frame_vulnerability,
        'masonry' => calculate_masonry_vulnerability,
        'concrete' => calculate_concrete_vulnerability,
        'mobile_home' => calculate_mobile_home_vulnerability
      },
      'commercial' => {
        'steel_frame' => calculate_steel_frame_vulnerability,
        'concrete' => calculate_concrete_vulnerability,
        'mixed_use' => calculate_mixed_use_vulnerability
      },
      'industrial' => {
        'steel_frame' => calculate_steel_frame_vulnerability,
        'pre_engineered' => calculate_pre_engineered_vulnerability,
        'heavy_industrial' => calculate_heavy_industrial_vulnerability
      },
      'critical_infrastructure' => {
        'hospital' => calculate_hospital_vulnerability,
        'school' => calculate_school_vulnerability,
        'emergency_services' => calculate_emergency_services_vulnerability
      }
    }
    
    vulnerability_matrix
  end
  
  # Calculate economic impact estimates
  def calculate_economic_impact
    # Building damage costs
    building_damage_cost = calculate_building_damage_cost
    
    # Infrastructure damage
    infrastructure_cost = calculate_infrastructure_damage_cost
    
    # Business interruption
    business_interruption = calculate_business_interruption_cost
    
    # Emergency response costs
    emergency_response_cost = calculate_emergency_response_cost
    
    # Casualty costs (medical treatment, etc.)
    casualty_cost = calculate_casualty_cost
    
    total_cost = building_damage_cost + infrastructure_cost + 
                business_interruption + emergency_response_cost + casualty_cost
    
    {
      building_damage: building_damage_cost,
      infrastructure_damage: infrastructure_cost,
      business_interruption: business_interruption,
      emergency_response: emergency_response_cost,
      medical_costs: casualty_cost,
      total_economic_impact: total_cost,
      cost_per_capita: estimated_population_affected > 0 ? total_cost / estimated_population_affected : 0
    }
  end
  
  # Generate zone contour for mapping
  def generate_zone_contour(num_points: 36)
    contour_points = []
    angle_step = 360.0 / num_points
    
    (0...num_points).each do |i|
      angle = i * angle_step * Math::PI / 180.0
      
      # Calculate point coordinates
      dx = max_radius * Math.cos(angle)
      dy = max_radius * Math.sin(angle)
      
      # Convert to lat/lon
      lat = latitude + (dy / 111320.0)
      lon = longitude + (dx / (111320.0 * Math.cos(latitude * Math::PI / 180.0)))
      
      contour_points << { latitude: lat, longitude: lon, angle: angle * 180.0 / Math::PI }
    end
    
    contour_points
  end
  
  # Export zone data for GIS
  def to_geojson
    contour = generate_zone_contour
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
        overpressure_threshold: overpressure_threshold,
        max_radius: max_radius,
        zone_area: zone_area,
        damage_description: damage_description,
        population_affected: estimated_population_affected,
        evacuation_required: evacuation_required,
        risk_level: classify_risk_level,
        response_time: RESPONSE_TIMES[zone_type]
      }
    }
  end
  
  # Check if a point is within this zone
  def contains_point?(lat, lon)
    distance = calculate_distance_from_center(lat, lon)
    distance <= max_radius
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
  
  # Zone comparison and ranking
  def risk_score
    # Calculate composite risk score
    pressure_score = (overpressure_threshold / 100000.0) * 40 # Max 40 points for pressure
    population_score = [Math.log10(estimated_population_affected + 1) * 10, 30].min # Max 30 points
    area_score = [Math.log10(zone_area_km2 + 1) * 5, 20].min # Max 20 points
    infrastructure_score = critical_infrastructure_affected ? 10 : 0 # Max 10 points
    
    (pressure_score + population_score + area_score + infrastructure_score).round(1)
  end
  
  private
  
  # Estimate population density based on zone location and type
  def estimate_population_density
    # This would use actual demographic data in a real implementation
    base_density = case zone_type
                  when 'window_breakage'
                    1000 # Lower density outer areas
                  when 'structural_damage'
                    2000 # Moderate density
                  when 'building_collapse', 'fatality_threshold'
                    3000 # Higher density near potential source
                  else
                    1500 # Default
                  end
    
    # Adjust for time and location factors
    base_density * 0.8 # Assume 80% occupancy average
  end
  
  def calculate_time_of_day_factor
    # Adjust population based on time of day
    # This would use actual time in a real implementation
    hour = Time.current.hour
    
    case hour
    when 6..8, 17..19 # Rush hours
      1.2
    when 9..17 # Business hours
      0.8
    when 22..6 # Night hours
      1.0
    else
      1.0
    end
  end
  
  def calculate_occupancy_factor
    # Adjust for building occupancy rates
    case zone_type
    when 'window_breakage'
      0.7 # Lower occupancy in outer areas
    when 'structural_damage'
      0.8 # Moderate occupancy
    else
      0.9 # Higher occupancy in central areas
    end
  end
  
  def calculate_casualty_estimates
    return { fatalities: 0, injuries: 0 } if estimated_population_affected == 0
    
    # Base casualty rates by pressure level
    casualty_rates = case zone_type
                    when 'window_breakage'
                      { fatality_rate: 0.001, injury_rate: 0.05 }
                    when 'structural_damage'
                      { fatality_rate: 0.01, injury_rate: 0.2 }
                    when 'building_collapse'
                      { fatality_rate: 0.1, injury_rate: 0.5 }
                    when 'fatality_threshold'
                      { fatality_rate: 0.5, injury_rate: 0.8 }
                    when 'total_destruction'
                      { fatality_rate: 0.9, injury_rate: 0.95 }
                    else
                      { fatality_rate: 0.05, injury_rate: 0.3 }
                    end
    
    fatalities = (estimated_population_affected * casualty_rates[:fatality_rate]).round
    injuries = (estimated_population_affected * casualty_rates[:injury_rate]).round
    
    { fatalities: fatalities, injuries: injuries }
  end
  
  def generate_zone_boundary!
    # Generate simplified circular boundary
    # In a real implementation, this would account for terrain, obstacles, etc.
    boundary_points = generate_zone_contour(num_points: 72)
    
    # Store as JSON for database
    self.zone_boundary_coordinates = boundary_points.to_json
  end
  
  def calculate_zone_overlaps!
    # Find overlapping zones from the same explosion
    overlapping_zones = vapor_cloud_explosion.explosion_zones
                                           .where.not(id: id)
                                           .where('max_radius + ? >= ABS(max_radius - ?)', max_radius, max_radius)
    
    self.overlapping_zones = overlapping_zones.pluck(:zone_type).to_json
  end
  
  def classify_risk_level
    case overpressure_threshold
    when 0...3500
      'low'
    when 3500...20700
      'moderate'
    when 20700...48300
      'high'
    when 48300...103400
      'severe'
    else
      'extreme'
    end
  end
  
  def calculate_evacuation_time
    # Base evacuation time calculation
    base_time = max_radius / 2.0 # Assume 2 m/s average evacuation speed
    
    # Add time for warning and decision-making
    warning_time = 5 * 60 # 5 minutes
    decision_time = 10 * 60 # 10 minutes
    
    # Adjust for population density
    congestion_factor = [1.0 + (estimated_population_affected / 10000.0), 3.0].min
    
    movement_time = base_time * congestion_factor
    total_time = warning_time + decision_time + movement_time
    
    {
      warning_time: warning_time,
      decision_time: decision_time,
      movement_time: movement_time,
      total_time: total_time,
      clearance_time: total_time * 1.2 # Add buffer
    }
  end
  
  def parse_protective_actions
    if protective_actions.present?
      JSON.parse(protective_actions)
    else
      default_protective_actions
    end
  rescue JSON::ParserError
    default_protective_actions
  end
  
  def default_protective_actions
    case zone_type
    when 'window_breakage'
      ['Stay away from windows', 'Shelter indoors', 'Monitor emergency broadcasts']
    when 'structural_damage'
      ['Evacuate if possible', 'Seek sturdy shelter', 'Avoid damaged structures']
    when 'building_collapse', 'fatality_threshold', 'total_destruction'
      ['Immediate evacuation required', 'Emergency shelter', 'Medical response needed']
    else
      ['Monitor situation', 'Follow official instructions']
    end
  end
  
  # Vulnerability calculation methods for different structure types
  def calculate_wood_frame_vulnerability
    pressure_psi = overpressure_threshold * 0.000145038
    
    case pressure_psi
    when 0...1.0 then 0.05
    when 1.0...3.0 then 0.3
    when 3.0...7.0 then 0.7
    else 0.95
    end
  end
  
  def calculate_masonry_vulnerability
    pressure_psi = overpressure_threshold * 0.000145038
    
    case pressure_psi
    when 0...2.0 then 0.02
    when 2.0...5.0 then 0.4
    when 5.0...10.0 then 0.8
    else 0.98
    end
  end
  
  def calculate_concrete_vulnerability
    pressure_psi = overpressure_threshold * 0.000145038
    
    case pressure_psi
    when 0...3.0 then 0.01
    when 3.0...7.0 then 0.3
    when 7.0...15.0 then 0.7
    else 0.9
    end
  end
  
  def calculate_mobile_home_vulnerability
    pressure_psi = overpressure_threshold * 0.000145038
    
    case pressure_psi
    when 0...0.5 then 0.1
    when 0.5...2.0 then 0.6
    when 2.0...5.0 then 0.9
    else 0.99
    end
  end
  
  def calculate_steel_frame_vulnerability
    pressure_psi = overpressure_threshold * 0.000145038
    
    case pressure_psi
    when 0...4.0 then 0.02
    when 4.0...8.0 then 0.4
    when 8.0...20.0 then 0.8
    else 0.95
    end
  end
  
  def calculate_mixed_use_vulnerability
    # Average of relevant structure types
    (calculate_steel_frame_vulnerability + calculate_concrete_vulnerability) / 2.0
  end
  
  def calculate_pre_engineered_vulnerability
    # Similar to steel frame but slightly more vulnerable
    calculate_steel_frame_vulnerability * 1.2
  end
  
  def calculate_heavy_industrial_vulnerability
    # More robust than typical structures
    calculate_concrete_vulnerability * 0.7
  end
  
  def calculate_hospital_vulnerability
    # Critical infrastructure - more robust design
    calculate_concrete_vulnerability * 0.5
  end
  
  def calculate_school_vulnerability
    # Mixed construction, moderate robustness
    calculate_masonry_vulnerability * 0.8
  end
  
  def calculate_emergency_services_vulnerability
    # Hardened facilities
    calculate_concrete_vulnerability * 0.3
  end
  
  # Economic impact calculation methods
  def calculate_building_damage_cost
    # Simplified building damage cost calculation
    avg_building_value = 200_000 # USD per building
    buildings_per_km2 = 100
    total_buildings = (zone_area_km2 * buildings_per_km2).round
    
    damage_fraction = case zone_type
                     when 'window_breakage' then 0.05
                     when 'structural_damage' then 0.3
                     when 'building_collapse' then 0.7
                     else 0.5
                     end
    
    total_buildings * avg_building_value * damage_fraction
  end
  
  def calculate_infrastructure_damage_cost
    # Roads, utilities, etc.
    calculate_building_damage_cost * 0.2
  end
  
  def calculate_business_interruption_cost
    # Lost business activity
    daily_economic_activity = estimated_population_affected * 200 # USD per person per day
    interruption_days = case zone_type
                       when 'window_breakage' then 1
                       when 'structural_damage' then 7
                       when 'building_collapse' then 30
                       else 14
                       end
    
    daily_economic_activity * interruption_days
  end
  
  def calculate_emergency_response_cost
    # Emergency services costs
    base_cost = 50_000 # Base response cost
    population_factor = estimated_population_affected * 10
    
    base_cost + population_factor
  end
  
  def calculate_casualty_cost
    # Medical costs for casualties
    casualty_estimates = calculate_casualty_estimates
    
    fatality_cost = 1_000_000 # Statistical value of life
    injury_cost = 50_000 # Average injury treatment cost
    
    (casualty_estimates[:fatalities] * fatality_cost) + 
    (casualty_estimates[:injuries] * injury_cost)
  end
  
  # Helper methods for evacuation planning
  def find_shelter_locations
    # This would query actual shelter database
    # Placeholder implementation
    num_shelters_needed = [(estimated_population_affected / 500.0).ceil, 1].max
    
    (1..num_shelters_needed).map do |i|
      {
        id: "shelter_#{i}",
        capacity: 500,
        distance_km: max_radius / 1000.0 + (i * 2),
        type: 'emergency_shelter'
      }
    end
  end
  
  def calculate_evacuation_routes
    # Simplified route calculation
    # Would use actual road network in implementation
    [
      { route_id: 'north', direction: 0, capacity: estimated_population_affected * 0.4 },
      { route_id: 'east', direction: 90, capacity: estimated_population_affected * 0.3 },
      { route_id: 'south', direction: 180, capacity: estimated_population_affected * 0.2 },
      { route_id: 'west', direction: 270, capacity: estimated_population_affected * 0.1 }
    ]
  end
  
  def calculate_transportation_needs
    # Assume 30% of population needs assistance with transportation
    assisted_population = (estimated_population_affected * 0.3).round
    
    {
      bus_capacity_needed: (assisted_population / 50.0).ceil,
      medical_transport: (estimated_population_affected * 0.05).round,
      wheelchair_accessible: (estimated_population_affected * 0.02).round
    }
  end
  
  def estimate_special_needs_population
    # Population requiring special assistance
    {
      elderly: (estimated_population_affected * 0.15).round,
      disabled: (estimated_population_affected * 0.08).round,
      children_under_5: (estimated_population_affected * 0.06).round,
      medical_needs: (estimated_population_affected * 0.12).round
    }
  end
  
  def find_medical_facilities
    # Medical facilities within or near the zone
    [
      { name: 'Regional Hospital', distance_km: max_radius / 1000.0 + 5, capacity: 200 },
      { name: 'Emergency Clinic', distance_km: max_radius / 1000.0 + 2, capacity: 50 }
    ]
  end
  
  def calculate_emergency_response_needs
    {
      fire_departments: [(estimated_population_affected / 5000.0).ceil, 1].max,
      ambulances: [(estimated_population_affected / 1000.0).ceil, 1].max,
      police_units: [(estimated_population_affected / 2000.0).ceil, 1].max,
      hazmat_teams: zone_type.in?(['building_collapse', 'fatality_threshold', 'total_destruction']) ? 2 : 1
    }
  end
  
  def generate_public_messages
    {
      immediate: "EXPLOSION HAZARD: #{zone_type.humanize} zone. #{evacuation_required? ? 'EVACUATE IMMEDIATELY' : 'Shelter in place'}",
      detailed: "Blast zone with #{overpressure_threshold} Pa overpressure. #{damage_description}",
      actions: parse_protective_actions.join('. ')
    }
  end
  
  def calculate_buildings_at_risk
    # Estimate buildings in zone
    (zone_area_km2 * 100).round # Assume 100 buildings per km²
  end
  
  def assess_critical_infrastructure
    # Check if zone contains critical infrastructure
    # This would query infrastructure database
    overpressure_threshold >= VaporCloudExplosion::DAMAGE_THRESHOLDS['structural_damage']
  end
end