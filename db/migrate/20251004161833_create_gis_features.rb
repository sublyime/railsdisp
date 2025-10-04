class CreateGisFeatures < ActiveRecord::Migration[8.0]
  def change
    create_table :gis_features do |t|
      t.string :name, null: false
      t.string :feature_type, null: false
      t.text :properties
      t.text :geometry
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.references :map_layer, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :gis_features, :name
    add_index :gis_features, :feature_type
    add_index :gis_features, [:latitude, :longitude]
    
    # Spatial index for geometric queries
    add_index :gis_features, [:latitude, :longitude, :feature_type], name: 'index_gis_features_spatial'
  end
end
