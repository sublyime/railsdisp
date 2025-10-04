# ToxicologicalData model for AEGL, ERPG, PAC, and IDLH values
# Based on ALOHA Technical Documentation Chapter 2.1 - Toxicological Data

class ToxicologicalData < ApplicationRecord
  belongs_to :chemical
  
  validates :chemical_id, presence: true, uniqueness: true
  
  # Validation for positive values where present
  validates :aegl_1_10min, :aegl_1_30min, :aegl_1_1hr, :aegl_1_4hr, :aegl_1_8hr,
            :aegl_2_10min, :aegl_2_30min, :aegl_2_1hr, :aegl_2_4hr, :aegl_2_8hr,
            :aegl_3_10min, :aegl_3_30min, :aegl_3_1hr, :aegl_3_4hr, :aegl_3_8hr,
            :erpg_1, :erpg_2, :erpg_3,
            :pac_1_10min, :pac_1_30min, :pac_1_1hr, :pac_1_4hr, :pac_1_8hr,
            :pac_2_10min, :pac_2_30min, :pac_2_1hr, :pac_2_4hr, :pac_2_8hr,
            :pac_3_10min, :pac_3_30min, :pac_3_1hr, :pac_3_4hr, :pac_3_8hr,
            :idlh, :pel_twa, :pel_stel, :rel_twa, :rel_stel, :tlv_twa, :tlv_stel,
            numericality: { greater_than: 0 }, allow_nil: true
  
  # Get appropriate LOC for given exposure duration and severity level
  def level_of_concern(duration_minutes, severity_level = 3)
    case severity_level
    when 1 # Discomfort/mild effects
      get_guideline_by_duration(duration_minutes, 'aegl_1', 'pac_1')
    when 2 # Serious/irreversible effects  
      get_guideline_by_duration(duration_minutes, 'aegl_2', 'pac_2', 'erpg_2')
    when 3 # Life threatening
      get_guideline_by_duration(duration_minutes, 'aegl_3', 'pac_3', 'erpg_3', 'idlh')
    end
  end
  
  # Get AEGL value for duration and level
  def aegl_value(level, duration_minutes)
    case duration_minutes
    when 0..15
      send("aegl_#{level}_10min")
    when 16..45
      send("aegl_#{level}_30min") 
    when 46..90
      send("aegl_#{level}_1hr")
    when 91..300
      send("aegl_#{level}_4hr")
    else
      send("aegl_#{level}_8hr")
    end
  end
  
  # Get PAC value for duration and level
  def pac_value(level, duration_minutes)
    case duration_minutes
    when 0..15
      send("pac_#{level}_10min")
    when 16..45
      send("pac_#{level}_30min")
    when 46..90
      send("pac_#{level}_1hr") 
    when 91..300
      send("pac_#{level}_4hr")
    else
      send("pac_#{level}_8hr")
    end
  end
  
  # Get ERPG value (60-minute exposure only)
  def erpg_value(level)
    send("erpg_#{level}")
  end
  
  # Convert to mg/m³ if needed
  def convert_to_mg_m3(ppm_value, temperature_k = 288.15, pressure_pa = 101325)
    return nil unless ppm_value && chemical.molecular_weight
    
    chemical.ppm_to_mg_m3(ppm_value, temperature_k, pressure_pa)
  end
  
  # Get highest priority guideline for emergency response
  def emergency_response_guideline(duration_minutes = 60)
    # Priority: AEGL-3 > ERPG-3 > PAC-3 > IDLH
    aegl_value(3, duration_minutes) || 
    (duration_minutes.between?(30, 120) ? erpg_3 : nil) ||
    pac_value(3, duration_minutes) ||
    idlh
  end
  
  # Check if exposure guidelines are available
  def has_aegls?
    [aegl_1_1hr, aegl_2_1hr, aegl_3_1hr].any?(&:present?)
  end
  
  def has_erpgs?
    [erpg_1, erpg_2, erpg_3].any?(&:present?)
  end
  
  def has_pacs?
    [pac_1_1hr, pac_2_1hr, pac_3_1hr].any?(&:present?)
  end
  
  def has_occupational_limits?
    [pel_twa, rel_twa, tlv_twa].any?(&:present?)
  end
  
  # Get all available guidelines for a duration
  def available_guidelines(duration_minutes)
    guidelines = {}
    
    if has_aegls?
      guidelines[:aegl_1] = aegl_value(1, duration_minutes)
      guidelines[:aegl_2] = aegl_value(2, duration_minutes)
      guidelines[:aegl_3] = aegl_value(3, duration_minutes)
    end
    
    if has_erpgs? && duration_minutes.between?(30, 120)
      guidelines[:erpg_1] = erpg_1
      guidelines[:erpg_2] = erpg_2
      guidelines[:erpg_3] = erpg_3
    end
    
    if has_pacs?
      guidelines[:pac_1] = pac_value(1, duration_minutes)
      guidelines[:pac_2] = pac_value(2, duration_minutes)
      guidelines[:pac_3] = pac_value(3, duration_minutes)
    end
    
    guidelines[:idlh] = idlh if idlh.present?
    
    guidelines.compact
  end
  
  private
  
  def get_guideline_by_duration(duration_minutes, *guideline_types)
    guideline_types.each do |type|
      case type
      when /aegl_(\d)/
        level = $1.to_i
        value = aegl_value(level, duration_minutes)
        return value if value.present?
      when /pac_(\d)/
        level = $1.to_i
        value = pac_value(level, duration_minutes)
        return value if value.present?
      when /erpg_(\d)/
        level = $1.to_i
        # ERPGs are only valid for ~60 minute exposures
        if duration_minutes.between?(30, 120)
          value = erpg_value(level)
          return value if value.present?
        end
      when 'idlh'
        return idlh if idlh.present?
      end
    end
    nil
  end
end