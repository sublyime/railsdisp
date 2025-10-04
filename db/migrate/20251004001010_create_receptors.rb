class CreateReceptors < ActiveRecord::Migration[8.0]
  def change
    create_table :receptors do |t|
      t.references :dispersion_event, null: false, foreign_key: true
      t.string :name
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :distance_from_source
      t.decimal :concentration
      t.decimal :exposure_time
      t.string :health_impact_level
      t.text :notes

      t.timestamps
    end
  end
end
