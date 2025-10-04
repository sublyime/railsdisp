class CreateChemicalSolutions < ActiveRecord::Migration[8.0]
  def change
    create_table :chemical_solutions do |t|
      t.references :chemical, null: false, foreign_key: true, index: true
      t.string :solution_type # 'hydrochloric_acid', 'ammonia', 'nitric_acid', 'hydrofluoric_acid', 'oleum'
      
      # Concentration range (mass fraction)
      t.decimal :min_concentration, precision: 6, scale: 4 # 0.0 to 1.0
      t.decimal :max_concentration, precision: 6, scale: 4 # 0.0 to 1.0
      
      # Polynomial coefficients for temperature and concentration dependence
      # Value = C1 + C2*Temperature + C3*MassFraction + C4*MassFraction²
      
      # Density coefficients (kg/m³)
      t.decimal :density_c1, precision: 12, scale: 4
      t.decimal :density_c2, precision: 12, scale: 6
      t.decimal :density_c3, precision: 12, scale: 4
      t.decimal :density_c4, precision: 12, scale: 4
      
      # Heat capacity coefficients (J/kg·K)
      t.decimal :heat_capacity_c1, precision: 12, scale: 4
      t.decimal :heat_capacity_c2, precision: 12, scale: 6
      t.decimal :heat_capacity_c3, precision: 12, scale: 4
      t.decimal :heat_capacity_c4, precision: 12, scale: 4
      
      # Heat of vaporization coefficients (J/kg)
      t.decimal :heat_vaporization_c1, precision: 12, scale: 2
      t.decimal :heat_vaporization_c2, precision: 12, scale: 4
      t.decimal :heat_vaporization_c3, precision: 12, scale: 2
      t.decimal :heat_vaporization_c4, precision: 12, scale: 2
      
      # Vapor pressure data (stored as JSON tables)
      # Format: [{concentration: 0.2, temperature: 298, pressure: 1013}, ...]
      t.text :vapor_pressure_data
      
      # Temperature range for validity (K)
      t.decimal :min_temperature, precision: 8, scale: 2
      t.decimal :max_temperature, precision: 8, scale: 2
      
      # Data sources and notes
      t.string :data_source
      t.text :notes
      
      t.timestamps
    end
    
    add_index :chemical_solutions, [:chemical_id, :solution_type], unique: true
    add_index :chemical_solutions, [:solution_type, :min_concentration, :max_concentration]
  end
end