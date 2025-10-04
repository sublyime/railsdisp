class CreateSourceStrengthModels < ActiveRecord::Migration[8.0]
  def change
    # Table for comprehensive dispersion scenarios
    create_table :dispersion_scenarios do |t|
      # Basic identification
      t.string :name, null: false
      t.text :description
      t.string :scenario_id, null: false
      
      # Chemical reference
      t.references :chemical, null: false, foreign_key: true
      
      # Location data
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.decimal :elevation, precision: 8, scale: 2
      t.string :terrain_description
      
      # Source type and parameters
      t.string :source_type, null: false # 'direct', 'puddle', 'tank', 'pipeline'
      t.decimal :release_temperature, precision: 10, scale: 2
      t.decimal :ambient_temperature, precision: 10, scale: 2
      t.decimal :ambient_pressure, precision: 12, scale: 2
      t.decimal :relative_humidity, precision: 5, scale: 2
      t.decimal :wind_speed, precision: 8, scale: 2
      t.decimal :wind_direction, precision: 5, scale: 2
      
      # Release parameters
      t.decimal :total_mass_released, precision: 12, scale: 2
      t.decimal :release_duration, precision: 10, scale: 2
      t.decimal :release_height, precision: 8, scale: 2
      t.decimal :initial_release_rate, precision: 12, scale: 4
      
      # Calculation control
      t.string :calculation_status, default: 'pending'
      t.datetime :last_calculated_at
      t.text :calculation_notes
      t.json :calculation_parameters
      
      # Quality assurance
      t.string :data_source
      t.boolean :validated, default: false
      t.string :validation_notes
      
      t.timestamps
    end
    
    # Table for detailed source-specific parameters
    create_table :source_details do |t|
      # Link to scenario (one-to-one relationship)
      t.references :dispersion_scenario, null: false, foreign_key: true
      
      # Direct source parameters
      t.decimal :direct_release_area, precision: 10, scale: 4
      t.decimal :direct_release_velocity, precision: 10, scale: 4
      t.decimal :direct_jet_diameter, precision: 8, scale: 4
      t.decimal :direct_discharge_coefficient, precision: 6, scale: 4
      
      # Puddle source parameters
      t.decimal :puddle_area, precision: 12, scale: 4
      t.decimal :puddle_depth, precision: 8, scale: 4
      t.decimal :puddle_temperature, precision: 10, scale: 2
      t.decimal :ground_temperature, precision: 10, scale: 2
      t.decimal :heat_transfer_coefficient, precision: 10, scale: 6
      t.decimal :ground_thermal_conductivity, precision: 10, scale: 6
      t.decimal :ground_thermal_diffusivity, precision: 12, scale: 8
      t.boolean :puddle_spreading, default: true
      t.decimal :max_puddle_area, precision: 12, scale: 4
      
      # Tank source parameters
      t.decimal :tank_volume, precision: 12, scale: 2
      t.decimal :tank_pressure, precision: 12, scale: 2
      t.decimal :tank_temperature, precision: 10, scale: 2
      t.decimal :liquid_level, precision: 8, scale: 2
      t.decimal :tank_diameter, precision: 8, scale: 2
      t.decimal :tank_height, precision: 8, scale: 2
      t.decimal :hole_diameter, precision: 8, scale: 4
      t.decimal :hole_height, precision: 8, scale: 2
      t.string :hole_orientation # 'horizontal', 'vertical', 'bottom'
      t.decimal :discharge_coefficient, precision: 6, scale: 4, default: 0.61
      t.boolean :two_phase_flow, default: false
      
      # Pipeline source parameters
      t.decimal :pipe_diameter, precision: 8, scale: 4
      t.decimal :pipe_pressure, precision: 12, scale: 2
      t.decimal :pipe_temperature, precision: 10, scale: 2
      t.decimal :pipe_length, precision: 10, scale: 2
      t.decimal :pipe_roughness, precision: 10, scale: 8
      t.decimal :break_size, precision: 8, scale: 4
      t.string :break_type # 'guillotine', 'puncture', 'longitudinal'
      t.decimal :upstream_pressure, precision: 12, scale: 2
      t.decimal :downstream_pressure, precision: 12, scale: 2
      t.boolean :choked_flow, default: false
      
      # Environmental factors
      t.decimal :surface_roughness, precision: 8, scale: 6
      t.decimal :atmospheric_stability_class, precision: 3, scale: 1
      t.string :pasquill_stability # 'A', 'B', 'C', 'D', 'E', 'F'
      
      # Brighton evaporation model parameters
      t.decimal :convective_heat_transfer, precision: 10, scale: 6
      t.decimal :mass_transfer_coefficient, precision: 10, scale: 6
      t.decimal :evaporation_enhancement_factor, precision: 6, scale: 4, default: 1.0
      
      t.timestamps
    end
    
    # Table for time-stepped release calculations
    create_table :release_calculations do |t|
      # Link to scenario
      t.references :dispersion_scenario, null: false, foreign_key: true
      
      # Time step data
      t.integer :time_step, null: false
      t.decimal :time_elapsed, precision: 10, scale: 2, null: false
      t.decimal :time_interval, precision: 8, scale: 2, null: false
      
      # Mass balance
      t.decimal :instantaneous_release_rate, precision: 12, scale: 4
      t.decimal :cumulative_mass_released, precision: 12, scale: 2
      t.decimal :remaining_mass, precision: 12, scale: 2
      t.decimal :mass_fraction_vapor, precision: 6, scale: 4
      t.decimal :mass_fraction_liquid, precision: 6, scale: 4
      
      # Thermodynamic state
      t.decimal :mixture_temperature, precision: 10, scale: 2
      t.decimal :mixture_pressure, precision: 12, scale: 2
      t.decimal :mixture_density, precision: 10, scale: 4
      t.decimal :vapor_density, precision: 10, scale: 4
      t.decimal :liquid_density, precision: 10, scale: 4
      
      # Flow characteristics
      t.decimal :exit_velocity, precision: 10, scale: 4
      t.decimal :mass_flux, precision: 12, scale: 4
      t.decimal :momentum_flux, precision: 12, scale: 4
      t.decimal :energy_flux, precision: 15, scale: 4
      
      # Evaporation calculations (Brighton model)
      t.decimal :evaporation_rate, precision: 12, scale: 6
      t.decimal :heat_flux_convective, precision: 12, scale: 4
      t.decimal :heat_flux_conductive, precision: 12, scale: 4
      t.decimal :heat_flux_total, precision: 12, scale: 4
      
      # Dimensionless parameters
      t.decimal :reynolds_number, precision: 12, scale: 2
      t.decimal :froude_number, precision: 10, scale: 6
      t.decimal :weber_number, precision: 10, scale: 4
      t.decimal :mach_number, precision: 8, scale: 6
      t.decimal :richardson_number, precision: 10, scale: 6
      
      # Quality indicators
      t.decimal :calculation_uncertainty, precision: 6, scale: 4
      t.string :flow_regime # 'subsonic', 'choked', 'two_phase', 'flashing'
      t.boolean :calculation_converged, default: true
      t.text :calculation_warnings
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :dispersion_scenarios, [:chemical_id, :source_type], name: 'idx_scenarios_chemical_source'
    add_index :dispersion_scenarios, [:latitude, :longitude], name: 'idx_scenarios_location'
    add_index :dispersion_scenarios, :calculation_status, name: 'idx_scenarios_status'
    add_index :dispersion_scenarios, :scenario_id, unique: true, name: 'idx_scenarios_scenario_id'
    
    add_index :source_details, :dispersion_scenario_id, unique: true, name: 'idx_source_details_scenario_id'
    
    add_index :release_calculations, [:dispersion_scenario_id, :time_step], unique: true, name: 'idx_calculations_scenario_step'
    add_index :release_calculations, [:dispersion_scenario_id, :time_elapsed], name: 'idx_calculations_scenario_time'
    add_index :release_calculations, :flow_regime, name: 'idx_calculations_flow_regime'
  end
end
