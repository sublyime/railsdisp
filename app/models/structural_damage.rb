# Structural Damage model for assessing building-specific blast effects
# Links explosion effects to individual buildings and structures
class StructuralDamage < ApplicationRecord
  belongs_to :vapor_cloud_explosion
  belongs_to :building
  
  # Delegate to explosion and building for convenience
  delegate :dispersion_scenario, :chemical, to: :vapor_cloud_explosion
  delegate :latitude, :longitude, :building_type, :height, :area, to: :building
  
  # Validation
  validates :structure_type, :incident_overpressure, presence: true
  validates :incident_overpressure, numericality: { greater_than: 0 }
  validates :damage_state, inclusion: { in: %w[none light moderate severe complete] }
  validates :construction_type, inclusion: { 
    in: %w[wood_frame steel_frame concrete masonry mixed unreinforced_masonry mobile_home unknown] 
  }
  validates :damage_probability, :fatality_probability, :serious_injury_probability,
            numericality: { in: 0..1 }, allow_nil: true
  
  # Scopes for analysis
  scope :by_damage_state, ->(state) { where(damage_state: state) }
  scope :by_construction_type, ->(type) { where(construction_type: type) }
  scope :high_damage_probability, -> { where('damage_probability > ?', 0.5) }
  scope :requires_search_rescue, -> { where(search_rescue_required: true) }
  scope :requires_medical_response, -> { where(medical_response_required: true) }
  scope :requires_inspection, -> { where(structural_inspection_required: true) }
  scope :critical_infrastructure, -> { joins(:building).where(buildings: { building_type: 'critical' }) }
  
  # Damage state thresholds by construction type (Pa)
  DAMAGE_THRESHOLDS = {
    'wood_frame' => {
      'light' => 2400,    # 0.35 psi - minor damage
      'moderate' => 6900, # 1.0 psi - moderate damage
      'severe' => 20700,  # 3.0 psi - major damage
      'complete' => 48300 # 7.0 psi - collapse
    },
    'steel_frame' => {
      'light' => 6900,    # 1.0 psi
      'moderate' => 20700, # 3.0 psi
      'severe' => 48300,  # 7.0 psi
      'complete' => 103400 # 15.0 psi
    },
    'concrete' => {
      'light' => 13800,   # 2.0 psi
      'moderate' => 34500, # 5.0 psi
      'severe' => 69000,  # 10.0 psi
      'complete' => 138000 # 20.0 psi
    },
    'masonry' => {
      'light' => 3500,    # 0.5 psi
      'moderate' => 13800, # 2.0 psi
      'severe' => 34500,  # 5.0 psi
      'complete' => 69000 # 10.0 psi
    },
    'unreinforced_masonry' => {
      'light' => 1700,    # 0.25 psi
      'moderate' => 6900, # 1.0 psi
      'severe' => 20700,  # 3.0 psi
      'complete' => 34500 # 5.0 psi
    },
    'mobile_home' => {
      'light' => 1700,    # 0.25 psi
      'moderate' => 3500, # 0.5 psi
      'severe' => 10300,  # 1.5 psi
      'complete' => 20700 # 3.0 psi
    }
  }.freeze
  
  # Building vulnerability factors
  VULNERABILITY_FACTORS = {
    'age' => {
      'new' => 0.8,      # Built after 2000
      'modern' => 1.0,   # Built 1980-2000
      'older' => 1.2,    # Built 1960-1980
      'old' => 1.5       # Built before 1960
    },
    'condition' => {
      'excellent' => 0.8,
      'good' => 1.0,
      'fair' => 1.3,
      'poor' => 1.8
    },
    'occupancy' => {
      'single_family' => 1.0,
      'multi_family' => 1.1,
      'commercial' => 0.9,
      'industrial' => 0.8,
      'institutional' => 0.7
    }
  }.freeze
  
  # Calculate comprehensive damage assessment
  def calculate_damage_assessment!
    # Determine damage state based on pressure and construction type
    self.damage_state = determine_damage_state
    
    # Calculate damage probability
    self.damage_probability = calculate_damage_probability
    
    # Assess human casualties
    calculate_casualty_probabilities!
    
    # Calculate economic losses
    self.estimated_repair_cost = calculate_repair_cost
    self.replacement_cost = calculate_replacement_cost
    self.business_interruption_cost = calculate_business_interruption
    
    # Determine required responses
    assess_response_requirements!
    
    # Calculate debris and secondary hazards
    assess_secondary_hazards!
    
    save!
  end
  
  # Determine damage state based on overpressure and construction
  def determine_damage_state
    thresholds = DAMAGE_THRESHOLDS[construction_type] || DAMAGE_THRESHOLDS['wood_frame']
    
    # Apply vulnerability factors
    adjusted_pressure = incident_overpressure * calculate_vulnerability_factor
    
    case adjusted_pressure
    when 0...thresholds['light']
      'none'
    when thresholds['light']...thresholds['moderate']
      'light'
    when thresholds['moderate']...thresholds['severe']
      'moderate'
    when thresholds['severe']...thresholds['complete']
      'severe'
    else
      'complete'
    end
  end
  
  # Calculate probability of damage occurring
  def calculate_damage_probability
    # Use fragility curves based on construction type and pressure
    thresholds = DAMAGE_THRESHOLDS[construction_type] || DAMAGE_THRESHOLDS['wood_frame']
    
    # Calculate median threshold for current damage state
    median_threshold = case damage_state
                      when 'light' then thresholds['light']
                      when 'moderate' then thresholds['moderate']
                      when 'severe' then thresholds['severe']
                      when 'complete' then thresholds['complete']
                      else return 0.0
                      end
    
    # Lognormal fragility function
    # P = Φ(ln(P/Pm) / β) where Pm is median threshold, β is standard deviation
    beta = 0.5 # Typical value for structural fragility
    
    if incident_overpressure <= 0
      0.0
    else
      ln_ratio = Math.log(incident_overpressure / median_threshold)
      probability = 0.5 * (1 + Math.erf(ln_ratio / (beta * Math.sqrt(2))))
      [[probability, 0.0].max, 1.0].min
    end
  end
  
  # Calculate human casualty probabilities
  def calculate_casualty_probabilities!
    # Base casualty rates depend on damage state and building occupancy
    base_rates = casualty_rates_by_damage_state
    
    # Adjust for building characteristics
    occupancy_factor = calculate_occupancy_factor
    protection_factor = calculate_protection_factor
    time_factor = calculate_time_of_day_factor
    
    # Calculate probabilities
    self.fatality_probability = [base_rates[:fatality] * occupancy_factor * 
                                protection_factor * time_factor, 1.0].min
    
    self.serious_injury_probability = [base_rates[:serious_injury] * occupancy_factor * 
                                      protection_factor * time_factor, 1.0].min
    
    # Calculate expected casualties if building population is known
    if building.respond_to?(:typical_occupancy) && building.typical_occupancy
      expected_occupancy = building.typical_occupancy * time_factor
      self.expected_fatalities = (expected_occupancy * fatality_probability).round
      self.expected_serious_injuries = (expected_occupancy * serious_injury_probability).round
    end
  end
  
  # Calculate economic costs
  def calculate_repair_cost
    return 0 if damage_state == 'none'
    
    # Base replacement cost
    base_cost = calculate_replacement_cost
    
    # Damage cost factors
    damage_cost_factors = {
      'light' => 0.05,
      'moderate' => 0.25,
      'severe' => 0.65,
      'complete' => 1.0
    }
    
    factor = damage_cost_factors[damage_state] || 0.0
    repair_cost = base_cost * factor
    
    # Add cleanup and debris removal costs
    cleanup_factor = case damage_state
                    when 'light' then 0.02
                    when 'moderate' then 0.05
                    when 'severe' then 0.15
                    when 'complete' then 0.25
                    else 0.0
                    end
    
    repair_cost * (1 + cleanup_factor)
  end
  
  def calculate_replacement_cost
    # Estimate building replacement cost
    cost_per_sqft = case structure_type
                   when 'residential' then 150  # USD per sq ft
                   when 'commercial' then 200
                   when 'industrial' then 100
                   when 'institutional' then 300
                   else 150
                   end
    
    building_area = building.area || estimate_building_area
    building_area * cost_per_sqft
  end
  
  def calculate_business_interruption
    return 0 unless structure_type.in?(['commercial', 'industrial'])
    
    # Daily revenue estimate
    daily_revenue = case structure_type
                   when 'commercial'
                     (building.area || 1000) * 0.5 # $0.50 per sq ft per day
                   when 'industrial'
                     (building.area || 1000) * 0.3 # $0.30 per sq ft per day
                   else
                     0
                   end
    
    # Interruption period based on damage
    interruption_days = case damage_state
                       when 'light' then 3
                       when 'moderate' then 14
                       when 'severe' then 90
                       when 'complete' then 365
                       else 0
                       end
    
    daily_revenue * interruption_days
  end
  
  # Assess response requirements
  def assess_response_requirements!
    # Search and rescue requirements
    self.search_rescue_required = damage_state.in?(['severe', 'complete']) &&
                                 (expected_fatalities || 0) + (expected_serious_injuries || 0) > 0
    
    # Medical response requirements
    self.medical_response_required = serious_injury_probability > 0.1 ||
                                   (expected_serious_injuries || 0) > 0
    
    # Structural inspection requirements
    self.structural_inspection_required = damage_state.in?(['moderate', 'severe', 'complete'])
    
    # Utility shutoff requirements
    assess_utility_shutoff_needs!
    
    # Demolition requirements
    self.demolition_required = damage_state == 'complete' ||
                              (damage_state == 'severe' && structure_type == 'unreinforced_masonry')
  end
  
  # Assess secondary hazards
  def assess_secondary_hazards!
    hazards = []
    
    # Debris hazards
    if damage_state.in?(['moderate', 'severe', 'complete'])
      hazards << 'debris_field'
      self.debris_radius = calculate_debris_radius
    end
    
    # Fire hazards
    if incident_overpressure >= 10000 && structure_type.in?(['residential', 'commercial'])
      hazards << 'fire_risk'
    end
    
    # Utility hazards
    if damage_state.in?(['severe', 'complete'])
      hazards << 'gas_leak_risk' if building_has_gas_service?
      hazards << 'electrical_hazard' if building_has_electrical_service?
    end
    
    # Structural collapse hazards
    if damage_state == 'severe'
      hazards << 'progressive_collapse_risk'
    end
    
    # Chemical hazards (if industrial)
    if structure_type == 'industrial' && damage_state.in?(['severe', 'complete'])
      hazards << 'hazmat_release_potential'
    end
    
    self.secondary_hazards = hazards.to_json
  end
  
  # Generate detailed damage report
  def generate_damage_report
    {
      building_info: {
        id: building.id,
        type: structure_type,
        construction: construction_type,
        location: [latitude, longitude],
        area: building.area,
        height: building.height
      },
      blast_effects: {
        incident_pressure: incident_overpressure,
        pressure_psi: incident_overpressure * 0.000145038,
        damage_state: damage_state,
        damage_probability: damage_probability
      },
      casualties: {
        fatality_probability: fatality_probability,
        injury_probability: serious_injury_probability,
        expected_fatalities: expected_fatalities,
        expected_injuries: expected_serious_injuries
      },
      economic_impact: {
        repair_cost: estimated_repair_cost,
        replacement_cost: replacement_cost,
        business_interruption: business_interruption_cost,
        total_cost: (estimated_repair_cost || 0) + (business_interruption_cost || 0)
      },
      response_requirements: {
        search_rescue: search_rescue_required,
        medical_response: medical_response_required,
        structural_inspection: structural_inspection_required,
        demolition: demolition_required
      },
      secondary_hazards: parse_secondary_hazards,
      protective_measures: generate_protective_measures
    }
  end
  
  # Export for GIS visualization
  def to_geojson
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      properties: {
        building_id: building.id,
        structure_type: structure_type,
        construction_type: construction_type,
        damage_state: damage_state,
        damage_probability: damage_probability,
        incident_overpressure: incident_overpressure,
        fatality_probability: fatality_probability,
        repair_cost: estimated_repair_cost,
        search_rescue_required: search_rescue_required,
        demolition_required: demolition_required
      }
    }
  end
  
  # Calculate shelter effectiveness
  def calculate_shelter_effectiveness
    # Assess how well the building provides blast protection
    protection_factor = case construction_type
                       when 'concrete' then 0.8
                       when 'steel_frame' then 0.7
                       when 'masonry' then 0.6
                       when 'wood_frame' then 0.4
                       when 'mobile_home' then 0.1
                       else 0.5
                       end
    
    # Adjust for damage state
    damage_reduction = case damage_state
                      when 'none' then 1.0
                      when 'light' then 0.9
                      when 'moderate' then 0.5
                      when 'severe' then 0.2
                      when 'complete' then 0.0
                      else 0.5
                      end
    
    effective_protection = protection_factor * damage_reduction
    
    {
      protection_factor: protection_factor,
      damage_reduction: damage_reduction,
      effective_protection: effective_protection,
      suitable_for_shelter: effective_protection > 0.6 && damage_state.in?(['none', 'light'])
    }
  end
  
  private
  
  # Calculate overall vulnerability factor
  def calculate_vulnerability_factor
    age_factor = VULNERABILITY_FACTORS['age']['modern'] # Default
    condition_factor = VULNERABILITY_FACTORS['condition']['good'] # Default
    occupancy_factor = VULNERABILITY_FACTORS['occupancy']['single_family'] # Default
    
    # Adjust for building height (taller buildings may be more vulnerable)
    height_factor = if building.height && building.height > 30
                     1.2 # More vulnerable
                   elsif building.height && building.height > 60
                     1.4 # Much more vulnerable
                   else
                     1.0 # Standard
                   end
    
    age_factor * condition_factor * occupancy_factor * height_factor
  end
  
  # Get base casualty rates by damage state
  def casualty_rates_by_damage_state
    case damage_state
    when 'none'
      { fatality: 0.0, serious_injury: 0.0 }
    when 'light'
      { fatality: 0.001, serious_injury: 0.01 }
    when 'moderate'
      { fatality: 0.01, serious_injury: 0.05 }
    when 'severe'
      { fatality: 0.1, serious_injury: 0.3 }
    when 'complete'
      { fatality: 0.5, serious_injury: 0.8 }
    else
      { fatality: 0.05, serious_injury: 0.2 }
    end
  end
  
  def calculate_occupancy_factor
    # Adjust casualty rates based on typical building occupancy
    case structure_type
    when 'residential'
      1.0 # Full occupancy assumption
    when 'commercial'
      0.3 # Partial occupancy during business hours
    when 'industrial'
      0.2 # Lower occupancy
    when 'institutional'
      0.8 # Higher occupancy (schools, hospitals)
    else
      0.5
    end
  end
  
  def calculate_protection_factor
    # How well the building protects occupants
    case construction_type
    when 'concrete', 'steel_frame'
      0.7 # Better protection
    when 'masonry'
      0.8 # Moderate protection
    when 'wood_frame'
      1.0 # Standard protection
    when 'mobile_home', 'unreinforced_masonry'
      1.3 # Poor protection
    else
      1.0
    end
  end
  
  def calculate_time_of_day_factor
    # Adjust for time of day (would use actual time in implementation)
    hour = Time.current.hour
    
    case structure_type
    when 'residential'
      case hour
      when 6..8, 18..22 then 1.0  # High occupancy
      when 9..17 then 0.3          # Low occupancy (work hours)
      when 23..5 then 0.9          # Night occupancy
      else 0.7
      end
    when 'commercial'
      case hour
      when 9..17 then 1.0          # Business hours
      when 18..22 then 0.3         # Evening
      when 23..8 then 0.1          # Night/early morning
      else 0.5
      end
    else
      0.5 # Default factor
    end
  end
  
  def estimate_building_area
    # Estimate area if not provided
    case structure_type
    when 'residential'
      2000 # sq ft typical house
    when 'commercial'
      5000 # sq ft typical commercial
    when 'industrial'
      10000 # sq ft typical industrial
    else
      3000 # Default
    end
  end
  
  def assess_utility_shutoff_needs!
    # Determine if utilities need emergency shutoff
    utility_shutoff_needed = damage_state.in?(['severe', 'complete']) ||
                           (damage_state == 'moderate' && 
                            construction_type.in?(['wood_frame', 'mobile_home']))
    
    self.utility_shutoff_required = utility_shutoff_needed
  end
  
  def calculate_debris_radius
    # Estimate debris field radius
    case damage_state
    when 'moderate'
      [building.height || 10, 10].max # At least 10m
    when 'severe'
      [(building.height || 10) * 1.5, 15].max # 1.5x height, min 15m
    when 'complete'
      [(building.height || 10) * 2.0, 25].max # 2x height, min 25m
    else
      0
    end
  end
  
  def building_has_gas_service?
    # Would check building records in real implementation
    structure_type.in?(['residential', 'commercial'])
  end
  
  def building_has_electrical_service?
    # Almost all buildings have electrical service
    true
  end
  
  def parse_secondary_hazards
    if secondary_hazards.present?
      JSON.parse(secondary_hazards)
    else
      []
    end
  rescue JSON::ParserError
    []
  end
  
  def generate_protective_measures
    measures = []
    
    case damage_state
    when 'none', 'light'
      measures << 'Monitor for delayed effects'
      measures << 'Check for gas leaks'
    when 'moderate'
      measures << 'Evacuate if structural damage visible'
      measures << 'Turn off utilities'
      measures << 'Professional inspection required'
    when 'severe', 'complete'
      measures << 'Immediate evacuation required'
      measures << 'Emergency utility shutoff'
      measures << 'Establish safety perimeter'
      measures << 'Search and rescue operations'
    end
    
    # Add hazard-specific measures
    hazards = parse_secondary_hazards
    
    if hazards.include?('fire_risk')
      measures << 'Fire suppression standby'
    end
    
    if hazards.include?('debris_field')
      measures << 'Clear debris safely'
    end
    
    if hazards.include?('hazmat_release_potential')
      measures << 'Hazmat team assessment'
    end
    
    measures
  end
end