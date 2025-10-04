class CreateBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :buildings do |t|
      t.string :name, null: false
      t.string :building_type, null: false
      t.decimal :height, precision: 8, scale: 2
      t.decimal :area, precision: 12, scale: 2
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.text :geometry
      t.references :map_layer, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :buildings, [:latitude, :longitude]
    add_index :buildings, :building_type
    add_index :buildings, :height
    
    # Spatial bounding box index for efficient queries
    add_index :buildings, [:latitude, :longitude, :map_layer_id], name: 'index_buildings_spatial'
  end
end
