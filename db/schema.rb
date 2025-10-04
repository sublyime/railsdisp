# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_04_001023) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chemicals", force: :cascade do |t|
    t.string "name"
    t.string "cas_number"
    t.decimal "molecular_weight"
    t.decimal "vapor_pressure"
    t.decimal "boiling_point"
    t.decimal "melting_point"
    t.decimal "density"
    t.string "state"
    t.string "hazard_class"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dispersion_calculations", force: :cascade do |t|
    t.bigint "dispersion_event_id", null: false
    t.bigint "weather_datum_id", null: false
    t.json "plume_data"
    t.datetime "calculation_timestamp"
    t.string "model_used"
    t.string "stability_class"
    t.decimal "effective_height"
    t.decimal "max_concentration"
    t.decimal "max_distance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_event_id"], name: "index_dispersion_calculations_on_dispersion_event_id"
    t.index ["weather_datum_id"], name: "index_dispersion_calculations_on_weather_datum_id"
  end

  create_table "dispersion_events", force: :cascade do |t|
    t.bigint "chemical_id", null: false
    t.bigint "location_id", null: false
    t.decimal "release_rate"
    t.decimal "release_volume"
    t.decimal "release_mass"
    t.decimal "release_duration"
    t.string "release_type"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chemical_id"], name: "index_dispersion_events_on_chemical_id"
    t.index ["location_id"], name: "index_dispersion_events_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "elevation"
    t.decimal "building_height"
    t.string "building_type"
    t.string "terrain_type"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "receptors", force: :cascade do |t|
    t.bigint "dispersion_event_id", null: false
    t.string "name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.decimal "distance_from_source"
    t.decimal "concentration"
    t.decimal "exposure_time"
    t.string "health_impact_level"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_event_id"], name: "index_receptors_on_dispersion_event_id"
  end

  create_table "weather_data", force: :cascade do |t|
    t.decimal "temperature"
    t.decimal "humidity"
    t.decimal "pressure"
    t.decimal "wind_speed"
    t.decimal "wind_direction"
    t.decimal "precipitation"
    t.decimal "cloud_cover"
    t.decimal "visibility"
    t.datetime "recorded_at"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "dispersion_calculations", "dispersion_events"
  add_foreign_key "dispersion_calculations", "weather_data"
  add_foreign_key "dispersion_events", "chemicals"
  add_foreign_key "dispersion_events", "locations"
  add_foreign_key "receptors", "dispersion_events"
end
