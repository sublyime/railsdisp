class CreateAtmosphericDispersionModels < ActiveRecord::Migration[8.0]
  def change
    # Table for atmospheric dispersion calculations
    create_table :atmospheric_dispersions do |t|
      # Link to scenario
      t.references :dispersion_scenario, null: false, foreign_key: true
      
      # Model selection and parameters
      t.string :dispersion_model, null: false # 'gaussian', 'heavy_gas', 'dense_gas'
      t.string :pasquill_stability_class, null: false # 'A', 'B', 'C', 'D', 'E', 'F'
      t.decimal :atmospheric_stability_parameter, precision: 8, scale: 4
      
      # Meteorological parameters
      t.decimal :wind_speed_at_release, precision: 8, scale: 2, null: false
      t.decimal :wind_speed_at_10m, precision: 8, scale: 2, null: false
      t.decimal :friction_velocity, precision: 8, scale: 4
      t.decimal :monin_obukhov_length, precision: 12, scale: 2
      t.decimal :surface_roughness_length, precision: 8, scale: 6
      t.decimal :boundary_layer_height, precision: 10, scale: 2
      
      # Plume characteristics
      t.decimal :effective_release_height, precision: 8, scale: 2, null: false
      t.decimal :plume_rise, precision: 8, scale: 2
      t.decimal :buoyancy_flux, precision: 12, scale: 4
      t.decimal :momentum_flux, precision: 12, scale: 4
      t.decimal :plume_centerline_height, precision: 8, scale: 2
      
      # Dispersion coefficients
      t.decimal :sigma_y_coefficient, precision: 10, scale: 6
      t.decimal :sigma_z_coefficient, precision: 10, scale: 6
      t.decimal :sigma_y_exponent, precision: 6, scale: 4
      t.decimal :sigma_z_exponent, precision: 6, scale: 4
      
      # Heavy gas specific parameters
      t.decimal :initial_cloud_radius, precision: 8, scale: 2
      t.decimal :cloud_height, precision: 8, scale: 2
      t.decimal :entrainment_coefficient, precision: 6, scale: 4
      t.decimal :density_ratio, precision: 8, scale: 4
      t.decimal :richardson_number, precision: 10, scale: 6
      t.decimal :froude_number, precision: 10, scale: 6
      
      # Calculation bounds
      t.decimal :max_downwind_distance, precision: 10, scale: 2, default: 10000.0
      t.decimal :max_crosswind_distance, precision: 10, scale: 2, default: 5000.0
      t.decimal :grid_resolution, precision: 8, scale: 2, default: 10.0
      t.integer :time_steps, default: 100
      t.decimal :calculation_time_step, precision: 8, scale: 2, default: 60.0
      
      # Model performance parameters
      t.boolean :include_depletion, default: false
      t.boolean :include_decay, default: false
      t.decimal :decay_constant, precision: 12, scale: 8
      t.boolean :include_deposition, default: false
      t.decimal :deposition_velocity, precision: 10, scale: 6
      
      # Quality control
      t.string :calculation_status, default: 'pending'
      t.datetime :last_calculated_at
      t.decimal :calculation_uncertainty, precision: 6, scale: 4
      t.text :calculation_warnings
      t.text :model_assumptions
      
      t.timestamps
    end
    
    # Table for detailed plume calculations at specific points
    create_table :plume_calculations do |t|
      # Link to atmospheric dispersion
      t.references :atmospheric_dispersion, null: false, foreign_key: true
      
      # Spatial coordinates
      t.decimal :downwind_distance, precision: 10, scale: 2, null: false
      t.decimal :crosswind_distance, precision: 10, scale: 2, null: false
      t.decimal :vertical_distance, precision: 8, scale: 2, null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      
      # Time dimension
      t.integer :time_step, null: false
      t.decimal :elapsed_time, precision: 10, scale: 2, null: false
      
      # Concentration calculations
      t.decimal :ground_level_concentration, precision: 15, scale: 8, null: false
      t.decimal :centerline_concentration, precision: 15, scale: 8
      t.decimal :maximum_concentration, precision: 15, scale: 8
      t.decimal :integrated_concentration, precision: 15, scale: 8
      t.string :concentration_units, default: 'mg/m3'
      
      # Dispersion parameters at this point
      t.decimal :sigma_y, precision: 10, scale: 4
      t.decimal :sigma_z, precision: 10, scale: 4
      t.decimal :plume_height, precision: 8, scale: 2
      t.decimal :plume_width, precision: 10, scale: 4
      t.decimal :plume_depth, precision: 8, scale: 2
      
      # Wind and dilution
      t.decimal :local_wind_speed, precision: 8, scale: 2
      t.decimal :dilution_factor, precision: 12, scale: 4
      t.decimal :air_density, precision: 8, scale: 4
      t.decimal :mixing_height_effect, precision: 6, scale: 4
      
      # Heavy gas specific calculations
      t.decimal :cloud_radius, precision: 8, scale: 2
      t.decimal :cloud_density, precision: 8, scale: 4
      t.decimal :entrainment_rate, precision: 10, scale: 6
      t.decimal :cloud_temperature, precision: 10, scale: 2
      
      # Arrival time and duration
      t.decimal :arrival_time, precision: 10, scale: 2
      t.decimal :passage_duration, precision: 10, scale: 2
      t.decimal :peak_concentration_time, precision: 10, scale: 2
      
      # Depletion and transformation
      t.decimal :depletion_factor, precision: 8, scale: 6, default: 1.0
      t.decimal :decay_factor, precision: 8, scale: 6, default: 1.0
      t.decimal :deposition_rate, precision: 12, scale: 8
      t.decimal :remaining_mass_fraction, precision: 8, scale: 6, default: 1.0
      
      t.timestamps
    end
    
    # Table for concentration contours and footprints
    create_table :concentration_contours do |t|
      # Link to atmospheric dispersion
      t.references :atmospheric_dispersion, null: false, foreign_key: true
      
      # Contour definition
      t.decimal :concentration_level, precision: 15, scale: 8, null: false
      t.string :concentration_units, default: 'mg/m3'
      t.string :contour_type # 'aegl_1', 'aegl_2', 'aegl_3', 'erpg_1', 'erpg_2', 'erpg_3', 'custom'
      t.decimal :exposure_duration, precision: 8, scale: 2 # minutes
      
      # Time dimension
      t.integer :time_step, null: false
      t.decimal :elapsed_time, precision: 10, scale: 2, null: false
      
      # Contour geometry (stored as GeoJSON or WKT)
      t.text :contour_geometry
      t.decimal :max_downwind_extent, precision: 10, scale: 2
      t.decimal :max_crosswind_extent, precision: 10, scale: 2
      t.decimal :contour_area, precision: 12, scale: 2
      
      # Population and impact estimates
      t.integer :estimated_population_affected
      t.decimal :affected_area_km2, precision: 10, scale: 4
      t.text :impact_zones # JSON array of impact zone descriptions
      
      # Calculation metadata
      t.boolean :calculation_converged, default: true
      t.decimal :calculation_accuracy, precision: 6, scale: 4
      t.text :calculation_notes
      
      t.timestamps
    end
    
    # Table for receptor-specific calculations
    create_table :receptor_calculations do |t|
      # Link to atmospheric dispersion and receptor
      t.references :atmospheric_dispersion, null: false, foreign_key: true
      t.references :receptor, null: false, foreign_key: true
      
      # Calculated concentrations
      t.decimal :peak_concentration, precision: 15, scale: 8, null: false
      t.decimal :time_weighted_average, precision: 15, scale: 8
      t.decimal :integrated_dose, precision: 15, scale: 8
      t.string :concentration_units, default: 'mg/m3'
      
      # Temporal characteristics
      t.decimal :arrival_time, precision: 10, scale: 2
      t.decimal :peak_time, precision: 10, scale: 2
      t.decimal :duration_above_threshold, precision: 10, scale: 2
      t.decimal :threshold_concentration, precision: 15, scale: 8
      
      # Health impact assessment
      t.string :health_impact_level # 'no_effect', 'mild', 'notable', 'disabling', 'life_threatening'
      t.decimal :aegl_fraction, precision: 8, scale: 4
      t.decimal :erpg_fraction, precision: 8, scale: 4
      t.decimal :pac_fraction, precision: 8, scale: 4
      t.text :health_impact_notes
      
      # Distance and direction from source
      t.decimal :distance_from_source, precision: 10, scale: 2
      t.decimal :angle_from_source, precision: 5, scale: 2
      t.boolean :in_primary_plume, default: true
      
      t.timestamps
    end
    
    # Indexes for performance optimization
    add_index :atmospheric_dispersions, [:dispersion_scenario_id, :dispersion_model], name: 'idx_atm_disp_scenario_model'
    add_index :atmospheric_dispersions, :pasquill_stability_class, name: 'idx_atm_disp_stability'
    add_index :atmospheric_dispersions, :calculation_status, name: 'idx_atm_disp_status'
    
    add_index :plume_calculations, [:atmospheric_dispersion_id, :time_step], name: 'idx_plume_calc_disp_time'
    add_index :plume_calculations, [:downwind_distance, :crosswind_distance], name: 'idx_plume_calc_spatial'
    add_index :plume_calculations, :ground_level_concentration, name: 'idx_plume_calc_concentration'
    add_index :plume_calculations, [:latitude, :longitude], name: 'idx_plume_calc_coordinates'
    
    add_index :concentration_contours, [:atmospheric_dispersion_id, :time_step], name: 'idx_contours_disp_time'
    add_index :concentration_contours, [:concentration_level, :contour_type], name: 'idx_contours_level_type'
    add_index :concentration_contours, :contour_area, name: 'idx_contours_area'
    
    add_index :receptor_calculations, [:atmospheric_dispersion_id, :receptor_id], unique: true, name: 'idx_receptor_calc_unique'
    add_index :receptor_calculations, :health_impact_level, name: 'idx_receptor_calc_impact'
    add_index :receptor_calculations, :peak_concentration, name: 'idx_receptor_calc_peak'
  end
end
