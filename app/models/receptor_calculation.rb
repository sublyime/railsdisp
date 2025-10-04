# Receptor-specific atmospheric dispersion calculations
# Links dispersion results to specific receptor locations with health impact assessment
class ReceptorCalculation < ApplicationRecord
  belongs_to :atmospheric_dispersion
  belongs_to :receptor
  
  # Validations
  validates :peak_concentration, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :concentration_units, inclusion: { in: %w[mg/m3 ppm ug/m3 g/m3] }
  validates :health_impact_level, inclusion: { 
    in: %w[no_effect mild notable disabling life_threatening unknown] 
  }
  validates :aegl_fraction, :erpg_fraction, :pac_fraction, 
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :distance_from_source, presence: true, numericality: { greater_than: 0 }
  
  # Scopes for analysis and filtering
  scope :by_health_impact, ->(level) { where(health_impact_level: level) }
  scope :exceeding_aegl, ->(level) { where("aegl_fraction >= ?", level) }
  scope :exceeding_erpg, ->(level) { where("erpg_fraction >= ?", level) }
  scope :within_distance, ->(max_dist) { where('distance_from_source <= ?', max_dist) }
  scope :affected, -> { where.not(health_impact_level: ['no_effect', 'unknown']) }
  scope :high_risk, -> { where(health_impact_level: ['disabling', 'life_threatening']) }
  scope :in_primary_plume, -> { where(in_primary_plume: true) }
  
  # Delegate to atmospheric dispersion, scenario, and chemical
  delegate :dispersion_scenario, to: :atmospheric_dispersion
  delegate :chemical, to: :atmospheric_dispersion
  delegate :pasquill_stability_class, to: :atmospheric_dispersion
  delegate :toxicological_data, to: :chemical
  
  # Concentration unit conversions
  def peak_concentration_mg_m3
    convert_to_mg_m3(peak_concentration)
  end
  
  def peak_concentration_ppm
    convert_to_ppm(peak_concentration)
  end
  
  def time_weighted_average_mg_m3
    return nil unless time_weighted_average
    convert_to_mg_m3(time_weighted_average)
  end
  
  def time_weighted_average_ppm
    return nil unless time_weighted_average
    convert_to_ppm(time_weighted_average)
  end
  
  # Health impact assessment methods
  def detailed_health_assessment
    return {} unless toxicological_data
    
    tox = toxicological_data
    peak_mg_m3 = peak_concentration_mg_m3
    twa_mg_m3 = time_weighted_average_mg_m3
    
    assessment = {
      concentrations: {
        peak_mg_m3: peak_mg_m3,
        peak_ppm: peak_concentration_ppm,
        twa_mg_m3: twa_mg_m3,
        twa_ppm: time_weighted_average_ppm,
        integrated_dose: integrated_dose
      },
      aegl_assessment: assess_against_aegl_guidelines(peak_mg_m3, twa_mg_m3),
      erpg_assessment: assess_against_erpg_guidelines(peak_mg_m3, twa_mg_m3),
      pac_assessment: assess_against_pac_guidelines(peak_mg_m3, twa_mg_m3),
      occupational_limits: assess_against_occupational_limits(twa_mg_m3),
      overall_risk: determine_overall_risk_level,
      protective_actions: recommend_protective_actions,
      medical_considerations: assess_medical_considerations
    }
    
    assessment
  end
  
  # Temporal analysis of exposure
  def exposure_profile
    {
      arrival_time_minutes: arrival_time,
      peak_time_minutes: peak_time,
      duration_above_threshold_minutes: duration_above_threshold,
      threshold_concentration: threshold_concentration,
      total_exposure_time: calculate_total_exposure_time,
      exposure_pattern: determine_exposure_pattern
    }
  end
  
  # Spatial relationship to source and plume
  def spatial_analysis
    {
      distance_from_source_m: distance_from_source,
      distance_from_source_km: distance_from_source / 1000.0,
      angle_from_source_degrees: angle_from_source,
      cardinal_direction: calculate_cardinal_direction,
      in_primary_plume: in_primary_plume,
      relative_position: determine_relative_position,
      plume_centerline_distance: calculate_plume_centerline_distance
    }
  end
  
  # Risk characterization
  def risk_characterization
    {
      health_impact_level: health_impact_level,
      aegl_exceedance: {
        aegl_1: aegl_fraction >= 1.0,
        aegl_2: aegl_fraction >= 1.0 && aegl_fraction >= aegl_2_fraction,
        aegl_3: aegl_fraction >= 1.0 && aegl_fraction >= aegl_3_fraction
      },
      erpg_exceedance: {
        erpg_1: erpg_fraction >= 1.0,
        erpg_2: erpg_fraction >= 1.0 && erpg_fraction >= erpg_2_fraction,
        erpg_3: erpg_fraction >= 1.0 && erpg_fraction >= erpg_3_fraction
      },
      protective_action_zones: determine_protective_action_zones,
      evacuation_recommendation: should_evacuate?,
      shelter_in_place_recommendation: should_shelter_in_place?
    }
  end
  
  # Uncertainty analysis
  def uncertainty_analysis
    base_uncertainty = atmospheric_dispersion.calculation_uncertainty || 0.1
    
    distance_factor = case distance_from_source
                     when 0..1000 then 1.0
                     when 1000..5000 then 1.2
                     else 1.5
                     end
    
    stability_factor = case pasquill_stability_class
                      when 'D' then 1.0  # Neutral - most reliable
                      when 'C', 'E' then 1.1
                      when 'B', 'F' then 1.3
                      when 'A' then 1.5  # Very unstable - highest uncertainty
                      end
    
    plume_factor = in_primary_plume ? 1.0 : 1.4
    
    total_uncertainty = base_uncertainty * distance_factor * stability_factor * plume_factor
    
    {
      total_uncertainty_factor: total_uncertainty,
      concentration_range_low: peak_concentration * (1 - total_uncertainty),
      concentration_range_high: peak_concentration * (1 + total_uncertainty),
      uncertainty_sources: {
        meteorological: base_uncertainty,
        distance_extrapolation: distance_factor - 1.0,
        atmospheric_stability: stability_factor - 1.0,
        plume_position: plume_factor - 1.0
      },
      confidence_level: calculate_confidence_level(total_uncertainty)
    }
  end
  
  # Emergency response recommendations
  def emergency_response_recommendations
    {
      immediate_actions: determine_immediate_actions,
      protective_equipment: recommend_protective_equipment,
      medical_monitoring: recommend_medical_monitoring,
      evacuation_priority: determine_evacuation_priority,
      decontamination_needs: assess_decontamination_needs,
      communication_messages: generate_public_messages
    }
  end
  
  # Data export for reporting and visualization
  def to_report_hash
    {
      receptor: {
        name: receptor.name,
        latitude: receptor.latitude,
        longitude: receptor.longitude,
        distance_m: distance_from_source,
        angle_degrees: angle_from_source
      },
      exposure: {
        peak_concentration_mg_m3: peak_concentration_mg_m3,
        peak_concentration_ppm: peak_concentration_ppm,
        time_weighted_average_mg_m3: time_weighted_average_mg_m3,
        arrival_time_min: arrival_time,
        peak_time_min: peak_time,
        duration_above_threshold_min: duration_above_threshold
      },
      health_impact: {
        level: health_impact_level,
        aegl_fraction: aegl_fraction,
        erpg_fraction: erpg_fraction,
        protective_actions_needed: protective_actions_needed?
      },
      quality: {
        in_primary_plume: in_primary_plume,
        uncertainty: uncertainty_analysis[:total_uncertainty_factor],
        confidence: uncertainty_analysis[:confidence_level]
      }
    }
  end
  
  private
  
  def convert_to_mg_m3(concentration)
    return concentration if concentration_units == 'mg/m3'
    
    case concentration_units
    when 'ppm'
      mol_weight = chemical.molecular_weight
      return nil unless mol_weight && mol_weight > 0
      concentration * mol_weight / 24.45
    when 'ug/m3'
      concentration / 1000.0
    when 'g/m3'
      concentration * 1000.0
    else
      concentration
    end
  end
  
  def convert_to_ppm(concentration)
    return concentration if concentration_units == 'ppm'
    
    mol_weight = chemical.molecular_weight
    return nil unless mol_weight && mol_weight > 0
    
    mg_m3_conc = convert_to_mg_m3(concentration)
    return nil unless mg_m3_conc
    
    mg_m3_conc * 24.45 / mol_weight
  end
  
  def assess_against_aegl_guidelines(peak_mg_m3, twa_mg_m3)
    return {} unless toxicological_data
    
    tox = toxicological_data
    
    # Use 1-hour AEGL values as default, or closest duration match
    {
      aegl_1: {
        guideline_mg_m3: tox.aegl_1_1hr,
        peak_fraction: peak_mg_m3 && tox.aegl_1_1hr ? peak_mg_m3 / tox.aegl_1_1hr : nil,
        twa_fraction: twa_mg_m3 && tox.aegl_1_1hr ? twa_mg_m3 / tox.aegl_1_1hr : nil,
        exceeded: (twa_mg_m3 && tox.aegl_1_1hr) ? twa_mg_m3 >= tox.aegl_1_1hr : false
      },
      aegl_2: {
        guideline_mg_m3: tox.aegl_2_1hr,
        peak_fraction: peak_mg_m3 && tox.aegl_2_1hr ? peak_mg_m3 / tox.aegl_2_1hr : nil,
        twa_fraction: twa_mg_m3 && tox.aegl_2_1hr ? twa_mg_m3 / tox.aegl_2_1hr : nil,
        exceeded: (twa_mg_m3 && tox.aegl_2_1hr) ? twa_mg_m3 >= tox.aegl_2_1hr : false
      },
      aegl_3: {
        guideline_mg_m3: tox.aegl_3_1hr,
        peak_fraction: peak_mg_m3 && tox.aegl_3_1hr ? peak_mg_m3 / tox.aegl_3_1hr : nil,
        twa_fraction: twa_mg_m3 && tox.aegl_3_1hr ? twa_mg_m3 / tox.aegl_3_1hr : nil,
        exceeded: (twa_mg_m3 && tox.aegl_3_1hr) ? twa_mg_m3 >= tox.aegl_3_1hr : false
      }
    }
  end
  
  def assess_against_erpg_guidelines(peak_mg_m3, twa_mg_m3)
    return {} unless toxicological_data
    
    tox = toxicological_data
    
    {
      erpg_1: {
        guideline_mg_m3: tox.erpg_1,
        peak_fraction: peak_mg_m3 && tox.erpg_1 ? peak_mg_m3 / tox.erpg_1 : nil,
        twa_fraction: twa_mg_m3 && tox.erpg_1 ? twa_mg_m3 / tox.erpg_1 : nil,
        exceeded: (twa_mg_m3 && tox.erpg_1) ? twa_mg_m3 >= tox.erpg_1 : false
      },
      erpg_2: {
        guideline_mg_m3: tox.erpg_2,
        peak_fraction: peak_mg_m3 && tox.erpg_2 ? peak_mg_m3 / tox.erpg_2 : nil,
        twa_fraction: twa_mg_m3 && tox.erpg_2 ? twa_mg_m3 / tox.erpg_2 : nil,
        exceeded: (twa_mg_m3 && tox.erpg_2) ? twa_mg_m3 >= tox.erpg_2 : false
      },
      erpg_3: {
        guideline_mg_m3: tox.erpg_3,
        peak_fraction: peak_mg_m3 && tox.erpg_3 ? peak_mg_m3 / tox.erpg_3 : nil,
        twa_fraction: twa_mg_m3 && tox.erpg_3 ? twa_mg_m3 / tox.erpg_3 : nil,
        exceeded: (twa_mg_m3 && tox.erpg_3) ? twa_mg_m3 >= tox.erpg_3 : false
      }
    }
  end
  
  def assess_against_pac_guidelines(peak_mg_m3, twa_mg_m3)
    # PAC assessment - placeholder for future implementation
    {}
  end
  
  def assess_against_occupational_limits(twa_mg_m3)
    return {} unless toxicological_data
    
    tox = toxicological_data
    
    {
      pel_twa: {
        guideline_mg_m3: tox.pel_twa,
        fraction: twa_mg_m3 && tox.pel_twa ? twa_mg_m3 / tox.pel_twa : nil,
        exceeded: (twa_mg_m3 && tox.pel_twa) ? twa_mg_m3 >= tox.pel_twa : false
      },
      tlv_twa: {
        guideline_mg_m3: tox.tlv_twa,
        fraction: twa_mg_m3 && tox.tlv_twa ? twa_mg_m3 / tox.tlv_twa : nil,
        exceeded: (twa_mg_m3 && tox.tlv_twa) ? twa_mg_m3 >= tox.tlv_twa : false
      },
      idlh: {
        guideline_mg_m3: tox.idlh,
        peak_fraction: peak_concentration_mg_m3 && tox.idlh ? peak_concentration_mg_m3 / tox.idlh : nil,
        exceeded: (peak_concentration_mg_m3 && tox.idlh) ? peak_concentration_mg_m3 >= tox.idlh : false
      }
    }
  end
  
  def determine_overall_risk_level
    case health_impact_level
    when 'life_threatening' then 4
    when 'disabling' then 3
    when 'notable' then 2
    when 'mild' then 1
    else 0
    end
  end
  
  def recommend_protective_actions
    actions = []
    
    case health_impact_level
    when 'life_threatening'
      actions << 'Immediate evacuation required'
      actions << 'Emergency medical attention'
      actions << 'Full protective equipment for responders'
    when 'disabling'
      actions << 'Evacuation recommended'
      actions << 'Medical monitoring required'
      actions << 'Respiratory protection required'
    when 'notable'
      actions << 'Shelter in place or evacuation'
      actions << 'Medical monitoring recommended'
      actions << 'Limit outdoor activities'
    when 'mild'
      actions << 'Minimize exposure'
      actions << 'Monitor for symptoms'
    end
    
    actions
  end
  
  def protective_actions_needed?
    !health_impact_level.in?(['no_effect', 'unknown'])
  end
  
  def calculate_cardinal_direction
    return 'Unknown' unless angle_from_source
    
    angle = angle_from_source % 360
    
    case angle
    when 0..22.5, 337.5..360 then 'N'
    when 22.5..67.5 then 'NE'
    when 67.5..112.5 then 'E'
    when 112.5..157.5 then 'SE'
    when 157.5..202.5 then 'S'
    when 202.5..247.5 then 'SW'
    when 247.5..292.5 then 'W'
    when 292.5..337.5 then 'NW'
    end
  end
  
  def calculate_confidence_level(uncertainty)
    case uncertainty
    when 0..0.2 then 'High'
    when 0.2..0.5 then 'Medium'
    else 'Low'
    end
  end
  
  def should_evacuate?
    health_impact_level.in?(['disabling', 'life_threatening'])
  end
  
  def should_shelter_in_place?
    health_impact_level == 'notable' && distance_from_source < 1000
  end
end