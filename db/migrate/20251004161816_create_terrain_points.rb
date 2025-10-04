class CreateTerrainPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :terrain_points do |t|
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.decimal :elevation, precision: 8, scale: 2, null: false
      t.boolean :interpolated, default: false, null: false
      t.string :data_source, null: false
      t.references :map_layer, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :terrain_points, [:latitude, :longitude]
    add_index :terrain_points, :elevation
    add_index :terrain_points, :data_source
    add_index :terrain_points, :interpolated
    
    # Spatial index for elevation interpolation queries
    add_index :terrain_points, [:latitude, :longitude, :elevation], name: 'index_terrain_points_spatial'
    
    # Unique constraint to prevent duplicate points
    add_index :terrain_points, [:latitude, :longitude, :map_layer_id], unique: true, name: 'index_terrain_points_unique_location'
  end
end
