class CreateComprehensiveChemicals < ActiveRecord::Migration[8.0]
  def change
    # Add comprehensive chemical properties to existing chemicals table
    add_column :chemicals, :formula, :string
    add_column :chemicals, :synonyms, :text # JSON array of alternative names
    
    # Physical Properties (required for dispersion modeling)
    add_column :chemicals, :critical_temperature, :decimal, precision: 10, scale: 2 # K
    add_column :chemicals, :critical_pressure, :decimal, precision: 12, scale: 2 # Pa
    add_column :chemicals, :critical_volume, :decimal, precision: 10, scale: 6 # m³/mol
    add_column :chemicals, :freezing_point, :decimal, precision: 10, scale: 2 # K
    add_column :chemicals, :normal_boiling_point, :decimal, precision: 10, scale: 2 # K
    
    # Temperature-dependent properties (stored as JSON coefficients)
    add_column :chemicals, :vapor_pressure_coeffs, :text # Antoine equation coefficients
    add_column :chemicals, :liquid_density_coeffs, :text # Polynomial coefficients
    add_column :chemicals, :gas_density_coeffs, :text # Ideal gas + corrections
    add_column :chemicals, :heat_of_vaporization_coeffs, :text # Temperature dependence
    add_column :chemicals, :liquid_heat_capacity_coeffs, :text # Cp liquid vs temperature
    add_column :chemicals, :vapor_heat_capacity_coeffs, :text # Cp vapor vs temperature
    
    # Flammability Properties
    add_column :chemicals, :lower_flammability_limit, :decimal, precision: 8, scale: 4 # vol %
    add_column :chemicals, :upper_flammability_limit, :decimal, precision: 8, scale: 4 # vol %
    add_column :chemicals, :heat_of_combustion, :decimal, precision: 12, scale: 2 # J/kg
    add_column :chemicals, :flash_point, :decimal, precision: 10, scale: 2 # K
    add_column :chemicals, :autoignition_temperature, :decimal, precision: 10, scale: 2 # K
    
    # Reactivity and Safety
    add_column :chemicals, :reactive_with_air, :boolean, default: false
    add_column :chemicals, :reactive_with_water, :boolean, default: false
    add_column :chemicals, :water_soluble, :boolean, default: false
    add_column :chemicals, :water_solubility, :decimal, precision: 10, scale: 2 # kg/m³
    add_column :chemicals, :safety_warnings, :text # JSON array
    
    # Transport Properties
    add_column :chemicals, :molecular_diffusivity, :decimal, precision: 10, scale: 8 # m²/s in air
    add_column :chemicals, :surface_tension, :decimal, precision: 8, scale: 6 # N/m
    add_column :chemicals, :viscosity_liquid, :decimal, precision: 10, scale: 8 # Pa·s
    add_column :chemicals, :viscosity_gas, :decimal, precision: 10, scale: 8 # Pa·s
    
    # Dispersion Model Parameters
    add_column :chemicals, :dispersion_model_preference, :string # 'gaussian', 'heavy_gas', 'auto'
    add_column :chemicals, :gamma_ratio, :decimal # Cp/Cv for gas calculations
    add_column :chemicals, :roughness_coefficient, :decimal, precision: 6, scale: 4 # m
    
    # Source and validation
    add_column :chemicals, :data_source, :string
    add_column :chemicals, :notes, :text
    add_column :chemicals, :verified, :boolean, default: false
    
    add_index :chemicals, [:name, :cas_number], unique: true, where: "cas_number IS NOT NULL"
  end
end