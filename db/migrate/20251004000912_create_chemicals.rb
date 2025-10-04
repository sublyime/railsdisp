class CreateChemicals < ActiveRecord::Migration[8.0]
  def change
    create_table :chemicals do |t|
      t.string :name
      t.string :cas_number
      t.decimal :molecular_weight
      t.decimal :vapor_pressure
      t.decimal :boiling_point
      t.decimal :melting_point
      t.decimal :density
      t.string :state
      t.string :hazard_class
      t.text :description

      t.timestamps
    end
  end
end
