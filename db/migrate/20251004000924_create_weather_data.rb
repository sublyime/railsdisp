class CreateWeatherData < ActiveRecord::Migration[8.0]
  def change
    create_table :weather_data do |t|
      t.decimal :temperature
      t.decimal :humidity
      t.decimal :pressure
      t.decimal :wind_speed
      t.decimal :wind_direction
      t.decimal :precipitation
      t.decimal :cloud_cover
      t.decimal :visibility
      t.datetime :recorded_at
      t.decimal :latitude
      t.decimal :longitude
      t.string :source

      t.timestamps
    end
  end
end
