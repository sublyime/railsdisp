class CreateDispersionCalculations < ActiveRecord::Migration[8.0]
  def change
    create_table :dispersion_calculations do |t|
      t.references :dispersion_event, null: false, foreign_key: true
      t.references :weather_datum, null: false, foreign_key: true
      t.json :plume_data
      t.datetime :calculation_timestamp
      t.string :model_used
      t.string :stability_class
      t.decimal :effective_height
      t.decimal :max_concentration
      t.decimal :max_distance

      t.timestamps
    end
  end
end
