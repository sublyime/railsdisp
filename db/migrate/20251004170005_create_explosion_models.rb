class CreateExplosionModels < ActiveRecord::Migration[8.0]
  def change
    # Table for vapor cloud explosion calculations
    create_table :vapor_cloud_explosions do |t|
      # Link to scenario
      t.references :dispersion_scenario, null: false, foreign_key: true
      
      # Cloud characteristics
      t.string :explosion_type, null: false # 'vapor_cloud', 'bleve', 'confined', 'unconfined'
      t.decimal :cloud_mass, precision: 12, scale: 2, null: false # kg
      t.decimal :cloud_volume, precision: 12, scale: 2 # m³
      t.decimal :cloud_radius, precision: 8, scale: 2 # m
      t.decimal :cloud_height, precision: 8, scale: 2 # m
      t.decimal :cloud_concentration, precision: 15, scale: 8 # kg/m³
      
      # Flammability parameters
      t.decimal :lower_flammability_limit, precision: 8, scale: 4, null: false # vol%
      t.decimal :upper_flammability_limit, precision: 8, scale: 4, null: false # vol%
      t.decimal :stoichiometric_concentration, precision: 8, scale: 4 # vol%
      t.decimal :minimum_ignition_energy, precision: 12, scale: 8 # J
      t.decimal :laminar_flame_speed, precision: 8, scale: 4 # m/s
      t.decimal :heat_of_combustion, precision: 12, scale: 2 # J/kg
      
      # Environmental conditions
      t.decimal :ambient_temperature, precision: 10, scale: 2, null: false # K
      t.decimal :ambient_pressure, precision: 12, scale: 2, null: false # Pa
      t.decimal :relative_humidity, precision: 5, scale: 2 # %
      t.decimal :wind_speed, precision: 8, scale: 2 # m/s
      t.string :atmospheric_stability_class # A, B, C, D, E, F
      
      # Ignition parameters
      t.decimal :ignition_delay_time, precision: 8, scale: 2 # seconds
      t.decimal :ignition_probability, precision: 6, scale: 4 # 0-1
      t.string :ignition_source_type # 'immediate', 'delayed', 'probabilistic'
      t.decimal :ignition_location_x, precision: 10, scale: 2 # m from release
      t.decimal :ignition_location_y, precision: 10, scale: 2 # m from release
      t.decimal :ignition_height, precision: 8, scale: 2 # m above ground
      
      # Baker-Strehlow-Tang model parameters
      t.decimal :turbulent_flame_speed, precision: 8, scale: 4 # m/s
      t.decimal :flame_acceleration_factor, precision: 8, scale: 4
      t.integer :reactivity_index # 1-6 scale
      t.decimal :obstacle_density, precision: 6, scale: 4 # obstacles per m²
      t.decimal :congestion_factor, precision: 6, scale: 4 # 0-1
      t.decimal :confinement_factor, precision: 6, scale: 4 # 0-1
      
      # Explosion characteristics
      t.decimal :maximum_overpressure, precision: 12, scale: 2 # Pa
      t.decimal :positive_phase_duration, precision: 8, scale: 4 # seconds
      t.decimal :negative_phase_duration, precision: 8, scale: 4 # seconds
      t.decimal :impulse_positive, precision: 12, scale: 4 # Pa·s
      t.decimal :impulse_negative, precision: 12, scale: 4 # Pa·s
      t.decimal :blast_wave_speed, precision: 10, scale: 2 # m/s
      
      # TNT equivalency
      t.decimal :tnt_equivalent_mass, precision: 12, scale: 2 # kg TNT
      t.decimal :efficiency_factor, precision: 6, scale: 4 # 0-1
      t.decimal :yield_factor, precision: 6, scale: 4 # 0-1
      
      # Calculation control
      t.decimal :max_calculation_distance, precision: 10, scale: 2, default: 5000.0 # m
      t.decimal :calculation_resolution, precision: 8, scale: 2, default: 10.0 # m
      t.integer :calculation_sectors, default: 36 # directional sectors
      
      # Quality control
      t.string :calculation_status, default: 'pending'
      t.datetime :last_calculated_at
      t.decimal :calculation_uncertainty, precision: 6, scale: 4
      t.text :calculation_warnings
      t.text :model_assumptions
      
      t.timestamps
    end
    
    # Table for blast pressure calculations at specific points
    create_table :blast_calculations do |t|
      # Link to explosion
      t.references :vapor_cloud_explosion, null: false, foreign_key: true
      
      # Spatial coordinates
      t.decimal :distance_from_ignition, precision: 10, scale: 2, null: false # m
      t.decimal :angle_from_ignition, precision: 5, scale: 2, null: false # degrees
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :elevation, precision: 8, scale: 2 # m above sea level
      
      # Blast wave parameters
      t.decimal :peak_overpressure, precision: 12, scale: 2, null: false # Pa
      t.decimal :side_on_pressure, precision: 12, scale: 2 # Pa
      t.decimal :reflected_pressure, precision: 12, scale: 2 # Pa
      t.decimal :dynamic_pressure, precision: 12, scale: 2 # Pa
      t.decimal :total_pressure, precision: 12, scale: 2 # Pa
      
      # Temporal characteristics
      t.decimal :arrival_time, precision: 10, scale: 4, null: false # seconds
      t.decimal :positive_duration, precision: 8, scale: 4 # seconds
      t.decimal :negative_duration, precision: 8, scale: 4 # seconds
      t.decimal :total_duration, precision: 8, scale: 4 # seconds
      
      # Impulse characteristics
      t.decimal :specific_impulse_positive, precision: 12, scale: 4 # Pa·s
      t.decimal :specific_impulse_negative, precision: 12, scale: 4 # Pa·s
      t.decimal :specific_impulse_total, precision: 12, scale: 4 # Pa·s
      
      # Wave propagation
      t.decimal :wave_speed, precision: 10, scale: 2 # m/s
      t.decimal :particle_velocity, precision: 10, scale: 4 # m/s
      t.decimal :mach_number, precision: 8, scale: 4
      t.decimal :shock_front_velocity, precision: 10, scale: 2 # m/s
      
      # Damage potential indicators
      t.decimal :damage_level, precision: 6, scale: 4 # 0-1 scale
      t.string :damage_category # 'light', 'moderate', 'severe', 'complete'
      t.decimal :lethality_probability, precision: 6, scale: 4 # 0-1
      t.decimal :injury_probability, precision: 6, scale: 4 # 0-1
      
      # Environmental effects
      t.decimal :ground_reflection_factor, precision: 6, scale: 4
      t.decimal :atmospheric_attenuation, precision: 8, scale: 6
      t.decimal :geometric_spreading_loss, precision: 8, scale: 4
      t.boolean :line_of_sight, default: true
      
      t.timestamps
    end
    
    # Table for explosion damage zones and contours
    create_table :explosion_zones do |t|
      # Link to explosion
      t.references :vapor_cloud_explosion, null: false, foreign_key: true
      
      # Zone definition
      t.decimal :overpressure_threshold, precision: 12, scale: 2, null: false # Pa
      t.string :zone_type, null: false # 'lethal', 'injury', 'damage', 'safe'
      t.string :damage_description
      t.decimal :lethality_percentage, precision: 5, scale: 2 # %
      
      # Zone geometry
      t.text :zone_geometry # GeoJSON or WKT polygon
      t.decimal :max_radius, precision: 10, scale: 2 # m
      t.decimal :min_radius, precision: 10, scale: 2 # m
      t.decimal :zone_area, precision: 12, scale: 2 # m²
      t.decimal :zone_area_km2, precision: 10, scale: 4 # km²
      
      # Impact assessment
      t.integer :estimated_population_affected
      t.integer :estimated_buildings_affected
      t.decimal :estimated_economic_loss, precision: 15, scale: 2 # currency units
      t.text :impact_description
      
      # Protective action recommendations
      t.text :protective_actions # JSON array
      t.boolean :evacuation_required, default: false
      t.decimal :evacuation_radius, precision: 10, scale: 2 # m
      t.decimal :shelter_radius, precision: 10, scale: 2 # m
      
      t.timestamps
    end
    
    # Table for structural damage calculations
    create_table :structural_damages do |t|
      # Link to explosion and building/structure
      t.references :vapor_cloud_explosion, null: false, foreign_key: true
      t.references :building, null: true, foreign_key: true
      
      # Structure characteristics
      t.string :structure_type # 'residential', 'commercial', 'industrial', 'critical'
      t.string :construction_type # 'wood_frame', 'steel_frame', 'concrete', 'masonry'
      t.decimal :structure_height, precision: 8, scale: 2 # m
      t.decimal :structure_area, precision: 12, scale: 2 # m²
      t.integer :occupancy_count
      
      # Blast loading
      t.decimal :incident_overpressure, precision: 12, scale: 2, null: false # Pa
      t.decimal :reflected_overpressure, precision: 12, scale: 2 # Pa
      t.decimal :impulse_loading, precision: 12, scale: 4 # Pa·s
      t.decimal :duration_loading, precision: 8, scale: 4 # seconds
      
      # Damage assessment
      t.string :damage_state # 'none', 'light', 'moderate', 'severe', 'complete'
      t.decimal :damage_probability, precision: 6, scale: 4 # 0-1
      t.decimal :collapse_probability, precision: 6, scale: 4 # 0-1
      t.decimal :repair_cost_estimate, precision: 12, scale: 2
      t.decimal :replacement_cost_estimate, precision: 12, scale: 2
      
      # Casualty estimates
      t.decimal :fatality_probability, precision: 6, scale: 4 # 0-1
      t.decimal :serious_injury_probability, precision: 6, scale: 4 # 0-1
      t.decimal :minor_injury_probability, precision: 6, scale: 4 # 0-1
      t.integer :estimated_fatalities
      t.integer :estimated_serious_injuries
      t.integer :estimated_minor_injuries
      
      # Response requirements
      t.boolean :search_rescue_required, default: false
      t.boolean :medical_response_required, default: false
      t.boolean :structural_inspection_required, default: false
      t.text :emergency_actions_needed
      
      t.timestamps
    end
    
    # Indexes for performance optimization
    add_index :vapor_cloud_explosions, [:dispersion_scenario_id, :explosion_type], name: 'idx_explosions_scenario_type'
    add_index :vapor_cloud_explosions, :calculation_status, name: 'idx_explosions_status'
    add_index :vapor_cloud_explosions, :cloud_mass, name: 'idx_explosions_mass'
    add_index :vapor_cloud_explosions, :maximum_overpressure, name: 'idx_explosions_pressure'
    
    add_index :blast_calculations, [:vapor_cloud_explosion_id, :distance_from_ignition], name: 'idx_blast_calc_explosion_distance'
    add_index :blast_calculations, :peak_overpressure, name: 'idx_blast_calc_pressure'
    add_index :blast_calculations, [:latitude, :longitude], name: 'idx_blast_calc_coordinates'
    add_index :blast_calculations, :damage_category, name: 'idx_blast_calc_damage'
    
    add_index :explosion_zones, [:vapor_cloud_explosion_id, :zone_type], name: 'idx_zones_explosion_type'
    add_index :explosion_zones, :overpressure_threshold, name: 'idx_zones_pressure_threshold'
    add_index :explosion_zones, :max_radius, name: 'idx_zones_radius'
    add_index :explosion_zones, :estimated_population_affected, name: 'idx_zones_population'
    
    add_index :structural_damages, [:vapor_cloud_explosion_id, :building_id], name: 'idx_damage_explosion_building'
    add_index :structural_damages, :damage_state, name: 'idx_damage_state'
    add_index :structural_damages, :structure_type, name: 'idx_damage_structure_type'
    add_index :structural_damages, [:fatality_probability, :serious_injury_probability], name: 'idx_damage_casualties'
  end
end
