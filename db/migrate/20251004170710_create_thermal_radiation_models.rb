class CreateThermalRadiationModels < ActiveRecord::Migration[8.0]
  def change
    # 1. Thermal radiation incidents table - main thermal events
    create_table :thermal_radiation_incidents do |t|
      t.references :dispersion_scenario, null: false, foreign_key: true, index: { name: 'idx_thermal_incidents_scenario' }
      
      # Incident classification
      t.string :incident_type, null: false # 'bleve_fireball', 'jet_fire', 'pool_fire', 'flash_fire'
      t.string :fire_category # 'pressurized_release', 'liquid_spill', 'tank_failure', 'pipeline_rupture'
      
      # Source parameters
      t.decimal :fuel_mass, precision: 15, scale: 6 # kg - total fuel involved
      t.decimal :fuel_volume, precision: 15, scale: 6 # m³ - liquid volume
      t.decimal :release_rate, precision: 15, scale: 6 # kg/s - mass release rate
      t.decimal :release_pressure, precision: 15, scale: 6 # Pa - release pressure
      t.decimal :release_temperature, precision: 15, scale: 6 # K - release temperature
      t.decimal :release_height, precision: 15, scale: 6 # m - height above ground
      
      # Fire geometry and characteristics
      t.decimal :fire_diameter, precision: 15, scale: 6 # m - fire diameter
      t.decimal :fire_height, precision: 15, scale: 6 # m - flame height
      t.decimal :fire_duration, precision: 15, scale: 6 # s - burn duration
      t.decimal :burn_rate, precision: 15, scale: 6 # kg/m²/s - surface burn rate
      
      # Radiative properties
      t.decimal :surface_emissive_power, precision: 15, scale: 6 # W/m² - SEP
      t.decimal :radiative_fraction, precision: 15, scale: 6 # dimensionless - fraction of heat radiated
      t.decimal :flame_temperature, precision: 15, scale: 6 # K - flame temperature
      t.decimal :transmissivity, precision: 15, scale: 6 # dimensionless - atmospheric transmissivity
      
      # Environmental conditions
      t.decimal :ambient_temperature, precision: 15, scale: 6 # K
      t.decimal :ambient_pressure, precision: 15, scale: 6 # Pa
      t.decimal :wind_speed, precision: 15, scale: 6 # m/s
      t.decimal :wind_direction, precision: 15, scale: 6 # degrees from north
      t.decimal :relative_humidity, precision: 15, scale: 6 # fraction
      
      # Calculation parameters
      t.decimal :view_factor_method # 1=solid_flame, 2=point_source, 3=tilted_cylinder
      t.decimal :atmospheric_absorption_coefficient, precision: 15, scale: 6 # m⁻¹
      t.decimal :maximum_heat_flux, precision: 15, scale: 6 # W/m² - peak heat flux
      t.decimal :maximum_range, precision: 15, scale: 6 # m - maximum significant range
      
      # Calculation settings
      t.integer :calculation_resolution, default: 50 # m - grid resolution
      t.integer :calculation_sectors, default: 36 # number of angular sectors
      t.decimal :max_calculation_distance, precision: 15, scale: 6, default: 2000.0 # m
      
      # Results summary
      t.string :calculation_status, default: 'pending' # 'pending', 'calculating', 'completed', 'failed'
      t.text :calculation_warnings
      t.datetime :last_calculated_at
      
      t.timestamps
    end
    
    # 2. Thermal calculations table - spatial heat flux calculations
    create_table :thermal_calculations do |t|
      t.references :thermal_radiation_incident, null: false, foreign_key: true, index: { name: 'idx_thermal_calcs_incident' }
      
      # Location information
      t.decimal :distance_from_source, precision: 15, scale: 6, null: false # m
      t.decimal :angle_from_source, precision: 15, scale: 6, null: false # degrees
      t.decimal :latitude, precision: 15, scale: 10, null: false
      t.decimal :longitude, precision: 15, scale: 10, null: false
      t.decimal :elevation, precision: 15, scale: 6 # m above sea level
      
      # View factor calculations
      t.decimal :view_factor, precision: 15, scale: 8, null: false # dimensionless
      t.decimal :solid_angle, precision: 15, scale: 8 # steradians
      t.decimal :projected_area, precision: 15, scale: 6 # m² - projected flame area
      
      # Heat flux calculations
      t.decimal :incident_heat_flux, precision: 15, scale: 6, null: false # W/m²
      t.decimal :absorbed_heat_flux, precision: 15, scale: 6 # W/m² - after atmospheric absorption
      t.decimal :net_heat_flux, precision: 15, scale: 6 # W/m² - net to target
      
      # Atmospheric effects
      t.decimal :atmospheric_transmittance, precision: 15, scale: 6 # dimensionless
      t.decimal :path_length, precision: 15, scale: 6 # m - atmospheric path length
      t.decimal :humidity_absorption, precision: 15, scale: 6 # additional humidity effects
      
      # Thermal dose calculations
      t.decimal :thermal_dose, precision: 15, scale: 6 # (W/m²)^(4/3) × s - thermal dose
      t.decimal :time_to_pain, precision: 15, scale: 6 # s - time to pain threshold
      t.decimal :time_to_2nd_degree_burn, precision: 15, scale: 6 # s - time to 2nd degree burn
      t.decimal :time_to_death, precision: 15, scale: 6 # s - time to lethality
      
      # Damage assessment
      t.string :thermal_damage_level # 'none', 'discomfort', 'pain', 'injury', 'severe_burn', 'lethality'
      t.decimal :burn_probability, precision: 15, scale: 6 # probability of burn injury
      t.decimal :lethality_probability, precision: 15, scale: 6 # probability of death
      
      # Protective effects
      t.boolean :line_of_sight, default: true
      t.decimal :shielding_factor, precision: 15, scale: 6, default: 1.0 # reduction due to obstacles
      t.text :protective_measures # JSON array of applicable measures
      
      t.timestamps
    end
    
    # 3. Thermal zones table - iso-heat flux contours
    create_table :thermal_zones do |t|
      t.references :thermal_radiation_incident, null: false, foreign_key: true, index: { name: 'idx_thermal_zones_incident' }
      
      # Zone definition
      t.decimal :heat_flux_threshold, precision: 15, scale: 6, null: false # W/m² - iso-heat flux level
      t.string :zone_type, null: false # 'no_effect', 'discomfort', 'pain', 'injury', 'lethality', 'equipment_damage'
      t.text :zone_description
      
      # Zone geometry
      t.decimal :max_radius, precision: 15, scale: 6, null: false # m - maximum radius
      t.decimal :min_radius, precision: 15, scale: 6, default: 0.0 # m - minimum radius (for annular zones)
      t.decimal :zone_area, precision: 15, scale: 6 # m² - total zone area
      t.decimal :zone_area_km2, precision: 15, scale: 6 # km² - area in square kilometers
      t.decimal :zone_perimeter, precision: 15, scale: 6 # m - zone perimeter
      
      # Population and impact assessment
      t.integer :estimated_population_affected, default: 0
      t.integer :estimated_casualties, default: 0
      t.integer :buildings_at_risk, default: 0
      t.boolean :evacuation_required, default: false
      t.decimal :evacuation_radius, precision: 15, scale: 6 # m - recommended evacuation distance
      
      # Response requirements
      t.boolean :emergency_response_required, default: false
      t.boolean :fire_suppression_required, default: false
      t.boolean :medical_response_required, default: false
      t.text :protective_actions # JSON array of recommended actions
      
      # Zone boundary data
      t.text :zone_boundary_coordinates # JSON array of lat/lon points
      t.text :overlapping_zones # JSON array of overlapping zone types
      
      t.timestamps
    end
    
    # 4. Equipment thermal damage table - specific equipment/structure damage
    create_table :equipment_thermal_damages do |t|
      t.references :thermal_radiation_incident, null: false, foreign_key: true, index: { name: 'idx_equip_thermal_incident' }
      t.references :building, null: true, foreign_key: true, index: { name: 'idx_equip_thermal_building' }
      
      # Equipment/structure information
      t.string :equipment_type, null: false # 'storage_tank', 'pressure_vessel', 'piping', 'structure', 'vehicle'
      t.string :material_type # 'steel', 'aluminum', 'concrete', 'plastic', 'composite'
      t.string :construction_standard # 'API650', 'ASME', 'concrete', 'wood_frame'
      
      # Geometric properties
      t.decimal :equipment_height, precision: 15, scale: 6 # m
      t.decimal :equipment_diameter, precision: 15, scale: 6 # m
      t.decimal :wall_thickness, precision: 15, scale: 6 # m
      t.decimal :surface_area, precision: 15, scale: 6 # m² - exposed surface area
      
      # Thermal properties
      t.decimal :thermal_conductivity, precision: 15, scale: 6 # W/m/K
      t.decimal :specific_heat, precision: 15, scale: 6 # J/kg/K
      t.decimal :density, precision: 15, scale: 6 # kg/m³
      t.decimal :emissivity, precision: 15, scale: 6 # surface emissivity
      t.decimal :critical_temperature, precision: 15, scale: 6 # K - failure temperature
      
      # Thermal exposure
      t.decimal :incident_heat_flux, precision: 15, scale: 6, null: false # W/m²
      t.decimal :exposure_duration, precision: 15, scale: 6 # s - duration of exposure
      t.decimal :surface_temperature, precision: 15, scale: 6 # K - calculated surface temperature
      t.decimal :time_to_failure, precision: 15, scale: 6 # s - time to structural failure
      
      # Damage assessment
      t.string :damage_state # 'none', 'minor', 'moderate', 'severe', 'failure'
      t.decimal :failure_probability, precision: 15, scale: 6 # probability of failure
      t.boolean :structural_failure, default: false
      t.boolean :contents_ignition, default: false # if equipment contains flammables
      t.boolean :escalation_potential, default: false # potential for domino effects
      
      # Economic impact
      t.decimal :replacement_cost, precision: 15, scale: 6 # USD - equipment replacement cost
      t.decimal :contents_value, precision: 15, scale: 6 # USD - value of contents
      t.decimal :business_interruption_cost, precision: 15, scale: 6 # USD - business losses
      
      # Response requirements
      t.boolean :fire_protection_required, default: false
      t.boolean :cooling_required, default: false
      t.boolean :emergency_isolation_required, default: false
      t.text :protective_measures # JSON array of protective measures
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :thermal_radiation_incidents, :incident_type, name: 'idx_thermal_incidents_type'
    add_index :thermal_radiation_incidents, :calculation_status, name: 'idx_thermal_incidents_status'
    add_index :thermal_radiation_incidents, [:fire_diameter, :fire_duration], name: 'idx_thermal_incidents_fire_params'
    
    add_index :thermal_calculations, :distance_from_source, name: 'idx_thermal_calcs_distance'
    add_index :thermal_calculations, :incident_heat_flux, name: 'idx_thermal_calcs_heat_flux'
    add_index :thermal_calculations, [:latitude, :longitude], name: 'idx_thermal_calcs_location'
    add_index :thermal_calculations, :thermal_damage_level, name: 'idx_thermal_calcs_damage'
    
    add_index :thermal_zones, :heat_flux_threshold, name: 'idx_thermal_zones_threshold'
    add_index :thermal_zones, :zone_type, name: 'idx_thermal_zones_type'
    add_index :thermal_zones, :evacuation_required, name: 'idx_thermal_zones_evacuation'
    add_index :thermal_zones, [:max_radius, :zone_area], name: 'idx_thermal_zones_geometry'
    
    add_index :equipment_thermal_damages, :equipment_type, name: 'idx_equip_thermal_type'
    add_index :equipment_thermal_damages, :damage_state, name: 'idx_equip_thermal_damage'
    add_index :equipment_thermal_damages, :failure_probability, name: 'idx_equip_thermal_failure'
    add_index :equipment_thermal_damages, [:structural_failure, :escalation_potential], name: 'idx_equip_thermal_escalation'
  end
end
