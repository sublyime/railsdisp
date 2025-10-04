class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :elevation
      t.decimal :building_height
      t.string :building_type
      t.string :terrain_type
      t.text :description

      t.timestamps
    end
  end
end
