class CreateMapLayers < ActiveRecord::Migration[8.0]
  def change
    create_table :map_layers do |t|
      t.string :name, null: false
      t.string :layer_type, null: false
      t.text :description
      t.boolean :visible, default: true, null: false
      t.integer :z_index, default: 0, null: false
      t.text :style_config

      t.timestamps
    end
    
    add_index :map_layers, :name, unique: true
    add_index :map_layers, :layer_type
    add_index :map_layers, :visible
    add_index :map_layers, :z_index
  end
end
