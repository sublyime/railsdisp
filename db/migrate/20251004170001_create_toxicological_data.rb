class CreateToxicologicalData < ActiveRecord::Migration[8.0]
  def change
    create_table :toxicological_data do |t|
      t.references :chemical, null: false, foreign_key: true, index: true
      
      # Acute Exposure Guideline Levels (AEGLs) - 10 min, 30 min, 1 hr, 4 hr, 8 hr
      t.decimal :aegl_1_10min, precision: 10, scale: 4 # ppm - discomfort
      t.decimal :aegl_1_30min, precision: 10, scale: 4
      t.decimal :aegl_1_1hr, precision: 10, scale: 4
      t.decimal :aegl_1_4hr, precision: 10, scale: 4
      t.decimal :aegl_1_8hr, precision: 10, scale: 4
      
      t.decimal :aegl_2_10min, precision: 10, scale: 4 # ppm - irreversible effects
      t.decimal :aegl_2_30min, precision: 10, scale: 4
      t.decimal :aegl_2_1hr, precision: 10, scale: 4
      t.decimal :aegl_2_4hr, precision: 10, scale: 4
      t.decimal :aegl_2_8hr, precision: 10, scale: 4
      
      t.decimal :aegl_3_10min, precision: 10, scale: 4 # ppm - life threatening
      t.decimal :aegl_3_30min, precision: 10, scale: 4
      t.decimal :aegl_3_1hr, precision: 10, scale: 4
      t.decimal :aegl_3_4hr, precision: 10, scale: 4
      t.decimal :aegl_3_8hr, precision: 10, scale: 4
      
      # Emergency Response Planning Guidelines (ERPGs) - 1 hour exposure
      t.decimal :erpg_1, precision: 10, scale: 4 # ppm - mild transient effects
      t.decimal :erpg_2, precision: 10, scale: 4 # ppm - serious effects
      t.decimal :erpg_3, precision: 10, scale: 4 # ppm - life threatening
      
      # Protective Action Criteria (PACs) - 10 min, 30 min, 1 hr, 4 hr, 8 hr
      t.decimal :pac_1_10min, precision: 10, scale: 4 # ppm
      t.decimal :pac_1_30min, precision: 10, scale: 4
      t.decimal :pac_1_1hr, precision: 10, scale: 4
      t.decimal :pac_1_4hr, precision: 10, scale: 4
      t.decimal :pac_1_8hr, precision: 10, scale: 4
      
      t.decimal :pac_2_10min, precision: 10, scale: 4
      t.decimal :pac_2_30min, precision: 10, scale: 4
      t.decimal :pac_2_1hr, precision: 10, scale: 4
      t.decimal :pac_2_4hr, precision: 10, scale: 4
      t.decimal :pac_2_8hr, precision: 10, scale: 4
      
      t.decimal :pac_3_10min, precision: 10, scale: 4
      t.decimal :pac_3_30min, precision: 10, scale: 4
      t.decimal :pac_3_1hr, precision: 10, scale: 4
      t.decimal :pac_3_4hr, precision: 10, scale: 4
      t.decimal :pac_3_8hr, precision: 10, scale: 4
      
      # Immediate Danger to Life and Health (IDLH)
      t.decimal :idlh, precision: 10, scale: 4 # ppm
      
      # Occupational Exposure Limits
      t.decimal :pel_twa, precision: 10, scale: 4 # ppm - Permissible Exposure Limit (8hr TWA)
      t.decimal :pel_stel, precision: 10, scale: 4 # ppm - Short Term Exposure Limit (15 min)
      t.decimal :rel_twa, precision: 10, scale: 4 # ppm - Recommended Exposure Limit (NIOSH)
      t.decimal :rel_stel, precision: 10, scale: 4 # ppm
      t.decimal :tlv_twa, precision: 10, scale: 4 # ppm - Threshold Limit Value (ACGIH)
      t.decimal :tlv_stel, precision: 10, scale: 4 # ppm
      
      # Concentration units and conversions
      t.string :concentration_units, default: 'ppm'
      t.decimal :mg_per_m3_conversion_factor, precision: 12, scale: 4
      
      # Data quality and sources
      t.string :aegl_source
      t.string :erpg_source  
      t.string :pac_source
      t.string :idlh_source
      t.text :data_notes
      t.date :data_updated
      
      t.timestamps
    end
    
    add_index :toxicological_data, [:chemical_id, :aegl_3_1hr]
    add_index :toxicological_data, [:chemical_id, :erpg_3]
  end
end