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

ActiveRecord::Schema[8.0].define(version: 2025_10_04_171927) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "atmospheric_dispersions", force: :cascade do |t|
    t.bigint "dispersion_scenario_id", null: false
    t.string "dispersion_model", null: false
    t.string "pasquill_stability_class", null: false
    t.decimal "atmospheric_stability_parameter", precision: 8, scale: 4
    t.decimal "wind_speed_at_release", precision: 8, scale: 2, null: false
    t.decimal "wind_speed_at_10m", precision: 8, scale: 2, null: false
    t.decimal "friction_velocity", precision: 8, scale: 4
    t.decimal "monin_obukhov_length", precision: 12, scale: 2
    t.decimal "surface_roughness_length", precision: 8, scale: 6
    t.decimal "boundary_layer_height", precision: 10, scale: 2
    t.decimal "effective_release_height", precision: 8, scale: 2, null: false
    t.decimal "plume_rise", precision: 8, scale: 2
    t.decimal "buoyancy_flux", precision: 12, scale: 4
    t.decimal "momentum_flux", precision: 12, scale: 4
    t.decimal "plume_centerline_height", precision: 8, scale: 2
    t.decimal "sigma_y_coefficient", precision: 10, scale: 6
    t.decimal "sigma_z_coefficient", precision: 10, scale: 6
    t.decimal "sigma_y_exponent", precision: 6, scale: 4
    t.decimal "sigma_z_exponent", precision: 6, scale: 4
    t.decimal "initial_cloud_radius", precision: 8, scale: 2
    t.decimal "cloud_height", precision: 8, scale: 2
    t.decimal "entrainment_coefficient", precision: 6, scale: 4
    t.decimal "density_ratio", precision: 8, scale: 4
    t.decimal "richardson_number", precision: 10, scale: 6
    t.decimal "froude_number", precision: 10, scale: 6
    t.decimal "max_downwind_distance", precision: 10, scale: 2, default: "10000.0"
    t.decimal "max_crosswind_distance", precision: 10, scale: 2, default: "5000.0"
    t.decimal "grid_resolution", precision: 8, scale: 2, default: "10.0"
    t.integer "time_steps", default: 100
    t.decimal "calculation_time_step", precision: 8, scale: 2, default: "60.0"
    t.boolean "include_depletion", default: false
    t.boolean "include_decay", default: false
    t.decimal "decay_constant", precision: 12, scale: 8
    t.boolean "include_deposition", default: false
    t.decimal "deposition_velocity", precision: 10, scale: 6
    t.string "calculation_status", default: "pending"
    t.datetime "last_calculated_at"
    t.decimal "calculation_uncertainty", precision: 6, scale: 4
    t.text "calculation_warnings"
    t.text "model_assumptions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculation_status"], name: "idx_atm_disp_status"
    t.index ["dispersion_scenario_id", "dispersion_model"], name: "idx_atm_disp_scenario_model"
    t.index ["dispersion_scenario_id"], name: "index_atmospheric_dispersions_on_dispersion_scenario_id"
    t.index ["pasquill_stability_class"], name: "idx_atm_disp_stability"
  end

  create_table "atmospheric_profiles", force: :cascade do |t|
    t.bigint "weather_observation_id", null: false
    t.string "profile_type", null: false
    t.datetime "profile_time", null: false
    t.decimal "surface_elevation", precision: 8, scale: 2
    t.json "height_levels"
    t.json "temperature_profile"
    t.json "wind_speed_profile"
    t.json "wind_direction_profile"
    t.json "humidity_profile"
    t.json "pressure_profile"
    t.decimal "boundary_layer_height", precision: 8, scale: 2
    t.decimal "capping_inversion_height", precision: 8, scale: 2
    t.decimal "surface_roughness", precision: 6, scale: 4
    t.decimal "heat_flux_surface", precision: 8, scale: 3
    t.decimal "momentum_flux_surface", precision: 8, scale: 6
    t.decimal "bulk_richardson_number", precision: 8, scale: 5
    t.decimal "gradient_richardson_number", precision: 8, scale: 5
    t.string "atmospheric_stability_category"
    t.decimal "vertical_dispersion_rate", precision: 8, scale: 5
    t.decimal "horizontal_dispersion_rate", precision: 8, scale: 5
    t.decimal "plume_rise_factor", precision: 6, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_time", "profile_type"], name: "index_atmospheric_profiles_on_time_type"
    t.index ["weather_observation_id", "profile_time"], name: "index_atmospheric_profiles_on_observation_time"
    t.index ["weather_observation_id"], name: "index_atmospheric_profiles_on_weather_observation_id"
  end

  create_table "blast_calculations", force: :cascade do |t|
    t.bigint "vapor_cloud_explosion_id", null: false
    t.decimal "distance_from_ignition", precision: 10, scale: 2, null: false
    t.decimal "angle_from_ignition", precision: 5, scale: 2, null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.decimal "elevation", precision: 8, scale: 2
    t.decimal "peak_overpressure", precision: 12, scale: 2, null: false
    t.decimal "side_on_pressure", precision: 12, scale: 2
    t.decimal "reflected_pressure", precision: 12, scale: 2
    t.decimal "dynamic_pressure", precision: 12, scale: 2
    t.decimal "total_pressure", precision: 12, scale: 2
    t.decimal "arrival_time", precision: 10, scale: 4, null: false
    t.decimal "positive_duration", precision: 8, scale: 4
    t.decimal "negative_duration", precision: 8, scale: 4
    t.decimal "total_duration", precision: 8, scale: 4
    t.decimal "specific_impulse_positive", precision: 12, scale: 4
    t.decimal "specific_impulse_negative", precision: 12, scale: 4
    t.decimal "specific_impulse_total", precision: 12, scale: 4
    t.decimal "wave_speed", precision: 10, scale: 2
    t.decimal "particle_velocity", precision: 10, scale: 4
    t.decimal "mach_number", precision: 8, scale: 4
    t.decimal "shock_front_velocity", precision: 10, scale: 2
    t.decimal "damage_level", precision: 6, scale: 4
    t.string "damage_category"
    t.decimal "lethality_probability", precision: 6, scale: 4
    t.decimal "injury_probability", precision: 6, scale: 4
    t.decimal "ground_reflection_factor", precision: 6, scale: 4
    t.decimal "atmospheric_attenuation", precision: 8, scale: 6
    t.decimal "geometric_spreading_loss", precision: 8, scale: 4
    t.boolean "line_of_sight", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["damage_category"], name: "idx_blast_calc_damage"
    t.index ["latitude", "longitude"], name: "idx_blast_calc_coordinates"
    t.index ["peak_overpressure"], name: "idx_blast_calc_pressure"
    t.index ["vapor_cloud_explosion_id", "distance_from_ignition"], name: "idx_blast_calc_explosion_distance"
    t.index ["vapor_cloud_explosion_id"], name: "index_blast_calculations_on_vapor_cloud_explosion_id"
  end

  create_table "buildings", force: :cascade do |t|
    t.string "name", null: false
    t.string "building_type", null: false
    t.decimal "height", precision: 8, scale: 2
    t.decimal "area", precision: 12, scale: 2
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.text "geometry"
    t.bigint "map_layer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["building_type"], name: "index_buildings_on_building_type"
    t.index ["height"], name: "index_buildings_on_height"
    t.index ["latitude", "longitude", "map_layer_id"], name: "index_buildings_spatial"
    t.index ["latitude", "longitude"], name: "index_buildings_on_latitude_and_longitude"
    t.index ["map_layer_id"], name: "index_buildings_on_map_layer_id"
  end

  create_table "chemical_solutions", force: :cascade do |t|
    t.bigint "chemical_id", null: false
    t.string "solution_type"
    t.decimal "min_concentration", precision: 6, scale: 4
    t.decimal "max_concentration", precision: 6, scale: 4
    t.decimal "density_c1", precision: 12, scale: 4
    t.decimal "density_c2", precision: 12, scale: 6
    t.decimal "density_c3", precision: 12, scale: 4
    t.decimal "density_c4", precision: 12, scale: 4
    t.decimal "heat_capacity_c1", precision: 12, scale: 4
    t.decimal "heat_capacity_c2", precision: 12, scale: 6
    t.decimal "heat_capacity_c3", precision: 12, scale: 4
    t.decimal "heat_capacity_c4", precision: 12, scale: 4
    t.decimal "heat_vaporization_c1", precision: 12, scale: 2
    t.decimal "heat_vaporization_c2", precision: 12, scale: 4
    t.decimal "heat_vaporization_c3", precision: 12, scale: 2
    t.decimal "heat_vaporization_c4", precision: 12, scale: 2
    t.text "vapor_pressure_data"
    t.decimal "min_temperature", precision: 8, scale: 2
    t.decimal "max_temperature", precision: 8, scale: 2
    t.string "data_source"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chemical_id", "solution_type"], name: "index_chemical_solutions_on_chemical_id_and_solution_type", unique: true
    t.index ["chemical_id"], name: "index_chemical_solutions_on_chemical_id"
    t.index ["solution_type", "min_concentration", "max_concentration"], name: "idx_on_solution_type_min_concentration_max_concentr_b7d73accfd"
  end

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
    t.string "formula"
    t.text "synonyms"
    t.decimal "critical_temperature", precision: 10, scale: 2
    t.decimal "critical_pressure", precision: 12, scale: 2
    t.decimal "critical_volume", precision: 10, scale: 6
    t.decimal "freezing_point", precision: 10, scale: 2
    t.decimal "normal_boiling_point", precision: 10, scale: 2
    t.text "vapor_pressure_coeffs"
    t.text "liquid_density_coeffs"
    t.text "gas_density_coeffs"
    t.text "heat_of_vaporization_coeffs"
    t.text "liquid_heat_capacity_coeffs"
    t.text "vapor_heat_capacity_coeffs"
    t.decimal "lower_flammability_limit", precision: 8, scale: 4
    t.decimal "upper_flammability_limit", precision: 8, scale: 4
    t.decimal "heat_of_combustion", precision: 12, scale: 2
    t.decimal "flash_point", precision: 10, scale: 2
    t.decimal "autoignition_temperature", precision: 10, scale: 2
    t.boolean "reactive_with_air", default: false
    t.boolean "reactive_with_water", default: false
    t.boolean "water_soluble", default: false
    t.decimal "water_solubility", precision: 10, scale: 2
    t.text "safety_warnings"
    t.decimal "molecular_diffusivity", precision: 10, scale: 8
    t.decimal "surface_tension", precision: 8, scale: 6
    t.decimal "viscosity_liquid", precision: 10, scale: 8
    t.decimal "viscosity_gas", precision: 10, scale: 8
    t.string "dispersion_model_preference"
    t.decimal "gamma_ratio"
    t.decimal "roughness_coefficient", precision: 6, scale: 4
    t.string "data_source"
    t.text "notes"
    t.boolean "verified", default: false
    t.index ["name", "cas_number"], name: "index_chemicals_on_name_and_cas_number", unique: true, where: "(cas_number IS NOT NULL)"
  end

  create_table "concentration_contours", force: :cascade do |t|
    t.bigint "atmospheric_dispersion_id", null: false
    t.decimal "concentration_level", precision: 15, scale: 8, null: false
    t.string "concentration_units", default: "mg/m3"
    t.string "contour_type"
    t.decimal "exposure_duration", precision: 8, scale: 2
    t.integer "time_step", null: false
    t.decimal "elapsed_time", precision: 10, scale: 2, null: false
    t.text "contour_geometry"
    t.decimal "max_downwind_extent", precision: 10, scale: 2
    t.decimal "max_crosswind_extent", precision: 10, scale: 2
    t.decimal "contour_area", precision: 12, scale: 2
    t.integer "estimated_population_affected"
    t.decimal "affected_area_km2", precision: 10, scale: 4
    t.text "impact_zones"
    t.boolean "calculation_converged", default: true
    t.decimal "calculation_accuracy", precision: 6, scale: 4
    t.text "calculation_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atmospheric_dispersion_id", "time_step"], name: "idx_contours_disp_time"
    t.index ["atmospheric_dispersion_id"], name: "index_concentration_contours_on_atmospheric_dispersion_id"
    t.index ["concentration_level", "contour_type"], name: "idx_contours_level_type"
    t.index ["contour_area"], name: "idx_contours_area"
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

  create_table "dispersion_scenarios", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "scenario_id", null: false
    t.bigint "chemical_id", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.decimal "elevation", precision: 8, scale: 2
    t.string "terrain_description"
    t.string "source_type", null: false
    t.decimal "release_temperature", precision: 10, scale: 2
    t.decimal "ambient_temperature", precision: 10, scale: 2
    t.decimal "ambient_pressure", precision: 12, scale: 2
    t.decimal "relative_humidity", precision: 5, scale: 2
    t.decimal "wind_speed", precision: 8, scale: 2
    t.decimal "wind_direction", precision: 5, scale: 2
    t.decimal "total_mass_released", precision: 12, scale: 2
    t.decimal "release_duration", precision: 10, scale: 2
    t.decimal "release_height", precision: 8, scale: 2
    t.decimal "initial_release_rate", precision: 12, scale: 4
    t.string "calculation_status", default: "pending"
    t.datetime "last_calculated_at"
    t.text "calculation_notes"
    t.json "calculation_parameters"
    t.string "data_source"
    t.boolean "validated", default: false
    t.string "validation_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculation_status"], name: "idx_scenarios_status"
    t.index ["chemical_id", "source_type"], name: "idx_scenarios_chemical_source"
    t.index ["chemical_id"], name: "index_dispersion_scenarios_on_chemical_id"
    t.index ["latitude", "longitude"], name: "idx_scenarios_location"
    t.index ["scenario_id"], name: "idx_scenarios_scenario_id", unique: true
  end

  create_table "equipment_thermal_damages", force: :cascade do |t|
    t.bigint "thermal_radiation_incident_id", null: false
    t.bigint "building_id"
    t.string "equipment_type", null: false
    t.string "material_type"
    t.string "construction_standard"
    t.decimal "equipment_height", precision: 15, scale: 6
    t.decimal "equipment_diameter", precision: 15, scale: 6
    t.decimal "wall_thickness", precision: 15, scale: 6
    t.decimal "surface_area", precision: 15, scale: 6
    t.decimal "thermal_conductivity", precision: 15, scale: 6
    t.decimal "specific_heat", precision: 15, scale: 6
    t.decimal "density", precision: 15, scale: 6
    t.decimal "emissivity", precision: 15, scale: 6
    t.decimal "critical_temperature", precision: 15, scale: 6
    t.decimal "incident_heat_flux", precision: 15, scale: 6, null: false
    t.decimal "exposure_duration", precision: 15, scale: 6
    t.decimal "surface_temperature", precision: 15, scale: 6
    t.decimal "time_to_failure", precision: 15, scale: 6
    t.string "damage_state"
    t.decimal "failure_probability", precision: 15, scale: 6
    t.boolean "structural_failure", default: false
    t.boolean "contents_ignition", default: false
    t.boolean "escalation_potential", default: false
    t.decimal "replacement_cost", precision: 15, scale: 6
    t.decimal "contents_value", precision: 15, scale: 6
    t.decimal "business_interruption_cost", precision: 15, scale: 6
    t.boolean "fire_protection_required", default: false
    t.boolean "cooling_required", default: false
    t.boolean "emergency_isolation_required", default: false
    t.text "protective_measures"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "idx_equip_thermal_building"
    t.index ["damage_state"], name: "idx_equip_thermal_damage"
    t.index ["equipment_type"], name: "idx_equip_thermal_type"
    t.index ["failure_probability"], name: "idx_equip_thermal_failure"
    t.index ["structural_failure", "escalation_potential"], name: "idx_equip_thermal_escalation"
    t.index ["thermal_radiation_incident_id"], name: "idx_equip_thermal_incident"
  end

  create_table "explosion_zones", force: :cascade do |t|
    t.bigint "vapor_cloud_explosion_id", null: false
    t.decimal "overpressure_threshold", precision: 12, scale: 2, null: false
    t.string "zone_type", null: false
    t.string "damage_description"
    t.decimal "lethality_percentage", precision: 5, scale: 2
    t.text "zone_geometry"
    t.decimal "max_radius", precision: 10, scale: 2
    t.decimal "min_radius", precision: 10, scale: 2
    t.decimal "zone_area", precision: 12, scale: 2
    t.decimal "zone_area_km2", precision: 10, scale: 4
    t.integer "estimated_population_affected"
    t.integer "estimated_buildings_affected"
    t.decimal "estimated_economic_loss", precision: 15, scale: 2
    t.text "impact_description"
    t.text "protective_actions"
    t.boolean "evacuation_required", default: false
    t.decimal "evacuation_radius", precision: 10, scale: 2
    t.decimal "shelter_radius", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["estimated_population_affected"], name: "idx_zones_population"
    t.index ["max_radius"], name: "idx_zones_radius"
    t.index ["overpressure_threshold"], name: "idx_zones_pressure_threshold"
    t.index ["vapor_cloud_explosion_id", "zone_type"], name: "idx_zones_explosion_type"
    t.index ["vapor_cloud_explosion_id"], name: "index_explosion_zones_on_vapor_cloud_explosion_id"
  end

  create_table "gis_features", force: :cascade do |t|
    t.string "name", null: false
    t.string "feature_type", null: false
    t.text "properties"
    t.text "geometry"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.bigint "map_layer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_type"], name: "index_gis_features_on_feature_type"
    t.index ["latitude", "longitude", "feature_type"], name: "index_gis_features_spatial"
    t.index ["latitude", "longitude"], name: "index_gis_features_on_latitude_and_longitude"
    t.index ["map_layer_id"], name: "index_gis_features_on_map_layer_id"
    t.index ["name"], name: "index_gis_features_on_name"
  end

  create_table "location_weather_cache", force: :cascade do |t|
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.string "location_hash", null: false
    t.bigint "primary_weather_station_id", null: false
    t.bigint "secondary_weather_station_id"
    t.bigint "tertiary_weather_station_id"
    t.decimal "primary_weight", precision: 4, scale: 3, default: "1.0"
    t.decimal "secondary_weight", precision: 4, scale: 3, default: "0.0"
    t.decimal "tertiary_weight", precision: 4, scale: 3, default: "0.0"
    t.decimal "primary_distance", precision: 8, scale: 3
    t.decimal "secondary_distance", precision: 8, scale: 3
    t.decimal "tertiary_distance", precision: 8, scale: 3
    t.datetime "last_updated_at"
    t.integer "update_frequency"
    t.boolean "auto_update", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_updated_at", "auto_update"], name: "index_location_weather_cache_on_update"
    t.index ["latitude", "longitude"], name: "index_location_weather_cache_on_coordinates"
    t.index ["location_hash"], name: "index_location_weather_cache_on_location_hash", unique: true
    t.index ["primary_weather_station_id"], name: "index_location_weather_cache_on_primary_weather_station_id"
    t.index ["secondary_weather_station_id"], name: "index_location_weather_cache_on_secondary_weather_station_id"
    t.index ["tertiary_weather_station_id"], name: "index_location_weather_cache_on_tertiary_weather_station_id"
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

  create_table "map_layers", force: :cascade do |t|
    t.string "name", null: false
    t.string "layer_type", null: false
    t.text "description"
    t.boolean "visible", default: true, null: false
    t.integer "z_index", default: 0, null: false
    t.text "style_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["layer_type"], name: "index_map_layers_on_layer_type"
    t.index ["name"], name: "index_map_layers_on_name", unique: true
    t.index ["visible"], name: "index_map_layers_on_visible"
    t.index ["z_index"], name: "index_map_layers_on_z_index"
  end

  create_table "plume_calculations", force: :cascade do |t|
    t.bigint "atmospheric_dispersion_id", null: false
    t.decimal "downwind_distance", precision: 10, scale: 2, null: false
    t.decimal "crosswind_distance", precision: 10, scale: 2, null: false
    t.decimal "vertical_distance", precision: 8, scale: 2, null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.integer "time_step", null: false
    t.decimal "elapsed_time", precision: 10, scale: 2, null: false
    t.decimal "ground_level_concentration", precision: 15, scale: 8, null: false
    t.decimal "centerline_concentration", precision: 15, scale: 8
    t.decimal "maximum_concentration", precision: 15, scale: 8
    t.decimal "integrated_concentration", precision: 15, scale: 8
    t.string "concentration_units", default: "mg/m3"
    t.decimal "sigma_y", precision: 10, scale: 4
    t.decimal "sigma_z", precision: 10, scale: 4
    t.decimal "plume_height", precision: 8, scale: 2
    t.decimal "plume_width", precision: 10, scale: 4
    t.decimal "plume_depth", precision: 8, scale: 2
    t.decimal "local_wind_speed", precision: 8, scale: 2
    t.decimal "dilution_factor", precision: 12, scale: 4
    t.decimal "air_density", precision: 8, scale: 4
    t.decimal "mixing_height_effect", precision: 6, scale: 4
    t.decimal "cloud_radius", precision: 8, scale: 2
    t.decimal "cloud_density", precision: 8, scale: 4
    t.decimal "entrainment_rate", precision: 10, scale: 6
    t.decimal "cloud_temperature", precision: 10, scale: 2
    t.decimal "arrival_time", precision: 10, scale: 2
    t.decimal "passage_duration", precision: 10, scale: 2
    t.decimal "peak_concentration_time", precision: 10, scale: 2
    t.decimal "depletion_factor", precision: 8, scale: 6, default: "1.0"
    t.decimal "decay_factor", precision: 8, scale: 6, default: "1.0"
    t.decimal "deposition_rate", precision: 12, scale: 8
    t.decimal "remaining_mass_fraction", precision: 8, scale: 6, default: "1.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atmospheric_dispersion_id", "time_step"], name: "idx_plume_calc_disp_time"
    t.index ["atmospheric_dispersion_id"], name: "index_plume_calculations_on_atmospheric_dispersion_id"
    t.index ["downwind_distance", "crosswind_distance"], name: "idx_plume_calc_spatial"
    t.index ["ground_level_concentration"], name: "idx_plume_calc_concentration"
    t.index ["latitude", "longitude"], name: "idx_plume_calc_coordinates"
  end

  create_table "receptor_calculations", force: :cascade do |t|
    t.bigint "atmospheric_dispersion_id", null: false
    t.bigint "receptor_id", null: false
    t.decimal "peak_concentration", precision: 15, scale: 8, null: false
    t.decimal "time_weighted_average", precision: 15, scale: 8
    t.decimal "integrated_dose", precision: 15, scale: 8
    t.string "concentration_units", default: "mg/m3"
    t.decimal "arrival_time", precision: 10, scale: 2
    t.decimal "peak_time", precision: 10, scale: 2
    t.decimal "duration_above_threshold", precision: 10, scale: 2
    t.decimal "threshold_concentration", precision: 15, scale: 8
    t.string "health_impact_level"
    t.decimal "aegl_fraction", precision: 8, scale: 4
    t.decimal "erpg_fraction", precision: 8, scale: 4
    t.decimal "pac_fraction", precision: 8, scale: 4
    t.text "health_impact_notes"
    t.decimal "distance_from_source", precision: 10, scale: 2
    t.decimal "angle_from_source", precision: 5, scale: 2
    t.boolean "in_primary_plume", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["atmospheric_dispersion_id", "receptor_id"], name: "idx_receptor_calc_unique", unique: true
    t.index ["atmospheric_dispersion_id"], name: "index_receptor_calculations_on_atmospheric_dispersion_id"
    t.index ["health_impact_level"], name: "idx_receptor_calc_impact"
    t.index ["peak_concentration"], name: "idx_receptor_calc_peak"
    t.index ["receptor_id"], name: "index_receptor_calculations_on_receptor_id"
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

  create_table "release_calculations", force: :cascade do |t|
    t.bigint "dispersion_scenario_id", null: false
    t.integer "time_step", null: false
    t.decimal "time_elapsed", precision: 10, scale: 2, null: false
    t.decimal "time_interval", precision: 8, scale: 2, null: false
    t.decimal "instantaneous_release_rate", precision: 12, scale: 4
    t.decimal "cumulative_mass_released", precision: 12, scale: 2
    t.decimal "remaining_mass", precision: 12, scale: 2
    t.decimal "mass_fraction_vapor", precision: 6, scale: 4
    t.decimal "mass_fraction_liquid", precision: 6, scale: 4
    t.decimal "mixture_temperature", precision: 10, scale: 2
    t.decimal "mixture_pressure", precision: 12, scale: 2
    t.decimal "mixture_density", precision: 10, scale: 4
    t.decimal "vapor_density", precision: 10, scale: 4
    t.decimal "liquid_density", precision: 10, scale: 4
    t.decimal "exit_velocity", precision: 10, scale: 4
    t.decimal "mass_flux", precision: 12, scale: 4
    t.decimal "momentum_flux", precision: 12, scale: 4
    t.decimal "energy_flux", precision: 15, scale: 4
    t.decimal "evaporation_rate", precision: 12, scale: 6
    t.decimal "heat_flux_convective", precision: 12, scale: 4
    t.decimal "heat_flux_conductive", precision: 12, scale: 4
    t.decimal "heat_flux_total", precision: 12, scale: 4
    t.decimal "reynolds_number", precision: 12, scale: 2
    t.decimal "froude_number", precision: 10, scale: 6
    t.decimal "weber_number", precision: 10, scale: 4
    t.decimal "mach_number", precision: 8, scale: 6
    t.decimal "richardson_number", precision: 10, scale: 6
    t.decimal "calculation_uncertainty", precision: 6, scale: 4
    t.string "flow_regime"
    t.boolean "calculation_converged", default: true
    t.text "calculation_warnings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_scenario_id", "time_elapsed"], name: "idx_calculations_scenario_time"
    t.index ["dispersion_scenario_id", "time_step"], name: "idx_calculations_scenario_step", unique: true
    t.index ["dispersion_scenario_id"], name: "index_release_calculations_on_dispersion_scenario_id"
    t.index ["flow_regime"], name: "idx_calculations_flow_regime"
  end

  create_table "source_details", force: :cascade do |t|
    t.bigint "dispersion_scenario_id", null: false
    t.decimal "direct_release_area", precision: 10, scale: 4
    t.decimal "direct_release_velocity", precision: 10, scale: 4
    t.decimal "direct_jet_diameter", precision: 8, scale: 4
    t.decimal "direct_discharge_coefficient", precision: 6, scale: 4
    t.decimal "puddle_area", precision: 12, scale: 4
    t.decimal "puddle_depth", precision: 8, scale: 4
    t.decimal "puddle_temperature", precision: 10, scale: 2
    t.decimal "ground_temperature", precision: 10, scale: 2
    t.decimal "heat_transfer_coefficient", precision: 10, scale: 6
    t.decimal "ground_thermal_conductivity", precision: 10, scale: 6
    t.decimal "ground_thermal_diffusivity", precision: 12, scale: 8
    t.boolean "puddle_spreading", default: true
    t.decimal "max_puddle_area", precision: 12, scale: 4
    t.decimal "tank_volume", precision: 12, scale: 2
    t.decimal "tank_pressure", precision: 12, scale: 2
    t.decimal "tank_temperature", precision: 10, scale: 2
    t.decimal "liquid_level", precision: 8, scale: 2
    t.decimal "tank_diameter", precision: 8, scale: 2
    t.decimal "tank_height", precision: 8, scale: 2
    t.decimal "hole_diameter", precision: 8, scale: 4
    t.decimal "hole_height", precision: 8, scale: 2
    t.string "hole_orientation"
    t.decimal "discharge_coefficient", precision: 6, scale: 4, default: "0.61"
    t.boolean "two_phase_flow", default: false
    t.decimal "pipe_diameter", precision: 8, scale: 4
    t.decimal "pipe_pressure", precision: 12, scale: 2
    t.decimal "pipe_temperature", precision: 10, scale: 2
    t.decimal "pipe_length", precision: 10, scale: 2
    t.decimal "pipe_roughness", precision: 10, scale: 8
    t.decimal "break_size", precision: 8, scale: 4
    t.string "break_type"
    t.decimal "upstream_pressure", precision: 12, scale: 2
    t.decimal "downstream_pressure", precision: 12, scale: 2
    t.boolean "choked_flow", default: false
    t.decimal "surface_roughness", precision: 8, scale: 6
    t.decimal "atmospheric_stability_class", precision: 3, scale: 1
    t.string "pasquill_stability"
    t.decimal "convective_heat_transfer", precision: 10, scale: 6
    t.decimal "mass_transfer_coefficient", precision: 10, scale: 6
    t.decimal "evaporation_enhancement_factor", precision: 6, scale: 4, default: "1.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_scenario_id"], name: "idx_source_details_scenario_id", unique: true
    t.index ["dispersion_scenario_id"], name: "index_source_details_on_dispersion_scenario_id"
  end

  create_table "structural_damages", force: :cascade do |t|
    t.bigint "vapor_cloud_explosion_id", null: false
    t.bigint "building_id"
    t.string "structure_type"
    t.string "construction_type"
    t.decimal "structure_height", precision: 8, scale: 2
    t.decimal "structure_area", precision: 12, scale: 2
    t.integer "occupancy_count"
    t.decimal "incident_overpressure", precision: 12, scale: 2, null: false
    t.decimal "reflected_overpressure", precision: 12, scale: 2
    t.decimal "impulse_loading", precision: 12, scale: 4
    t.decimal "duration_loading", precision: 8, scale: 4
    t.string "damage_state"
    t.decimal "damage_probability", precision: 6, scale: 4
    t.decimal "collapse_probability", precision: 6, scale: 4
    t.decimal "repair_cost_estimate", precision: 12, scale: 2
    t.decimal "replacement_cost_estimate", precision: 12, scale: 2
    t.decimal "fatality_probability", precision: 6, scale: 4
    t.decimal "serious_injury_probability", precision: 6, scale: 4
    t.decimal "minor_injury_probability", precision: 6, scale: 4
    t.integer "estimated_fatalities"
    t.integer "estimated_serious_injuries"
    t.integer "estimated_minor_injuries"
    t.boolean "search_rescue_required", default: false
    t.boolean "medical_response_required", default: false
    t.boolean "structural_inspection_required", default: false
    t.text "emergency_actions_needed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_structural_damages_on_building_id"
    t.index ["damage_state"], name: "idx_damage_state"
    t.index ["fatality_probability", "serious_injury_probability"], name: "idx_damage_casualties"
    t.index ["structure_type"], name: "idx_damage_structure_type"
    t.index ["vapor_cloud_explosion_id", "building_id"], name: "idx_damage_explosion_building"
    t.index ["vapor_cloud_explosion_id"], name: "index_structural_damages_on_vapor_cloud_explosion_id"
  end

  create_table "terrain_points", force: :cascade do |t|
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.decimal "elevation", precision: 8, scale: 2, null: false
    t.boolean "interpolated", default: false, null: false
    t.string "data_source", null: false
    t.bigint "map_layer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source"], name: "index_terrain_points_on_data_source"
    t.index ["elevation"], name: "index_terrain_points_on_elevation"
    t.index ["interpolated"], name: "index_terrain_points_on_interpolated"
    t.index ["latitude", "longitude", "elevation"], name: "index_terrain_points_spatial"
    t.index ["latitude", "longitude", "map_layer_id"], name: "index_terrain_points_unique_location", unique: true
    t.index ["latitude", "longitude"], name: "index_terrain_points_on_latitude_and_longitude"
    t.index ["map_layer_id"], name: "index_terrain_points_on_map_layer_id"
  end

  create_table "thermal_calculations", force: :cascade do |t|
    t.bigint "thermal_radiation_incident_id", null: false
    t.decimal "distance_from_source", precision: 15, scale: 6, null: false
    t.decimal "angle_from_source", precision: 15, scale: 6, null: false
    t.decimal "latitude", precision: 15, scale: 10, null: false
    t.decimal "longitude", precision: 15, scale: 10, null: false
    t.decimal "elevation", precision: 15, scale: 6
    t.decimal "view_factor", precision: 15, scale: 8, null: false
    t.decimal "solid_angle", precision: 15, scale: 8
    t.decimal "projected_area", precision: 15, scale: 6
    t.decimal "incident_heat_flux", precision: 15, scale: 6, null: false
    t.decimal "absorbed_heat_flux", precision: 15, scale: 6
    t.decimal "net_heat_flux", precision: 15, scale: 6
    t.decimal "atmospheric_transmittance", precision: 15, scale: 6
    t.decimal "path_length", precision: 15, scale: 6
    t.decimal "humidity_absorption", precision: 15, scale: 6
    t.decimal "thermal_dose", precision: 15, scale: 6
    t.decimal "time_to_pain", precision: 15, scale: 6
    t.decimal "time_to_2nd_degree_burn", precision: 15, scale: 6
    t.decimal "time_to_death", precision: 15, scale: 6
    t.string "thermal_damage_level"
    t.decimal "burn_probability", precision: 15, scale: 6
    t.decimal "lethality_probability", precision: 15, scale: 6
    t.boolean "line_of_sight", default: true
    t.decimal "shielding_factor", precision: 15, scale: 6, default: "1.0"
    t.text "protective_measures"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["distance_from_source"], name: "idx_thermal_calcs_distance"
    t.index ["incident_heat_flux"], name: "idx_thermal_calcs_heat_flux"
    t.index ["latitude", "longitude"], name: "idx_thermal_calcs_location"
    t.index ["thermal_damage_level"], name: "idx_thermal_calcs_damage"
    t.index ["thermal_radiation_incident_id"], name: "idx_thermal_calcs_incident"
  end

  create_table "thermal_radiation_incidents", force: :cascade do |t|
    t.bigint "dispersion_scenario_id", null: false
    t.string "incident_type", null: false
    t.string "fire_category"
    t.decimal "fuel_mass", precision: 15, scale: 6
    t.decimal "fuel_volume", precision: 15, scale: 6
    t.decimal "release_rate", precision: 15, scale: 6
    t.decimal "release_pressure", precision: 15, scale: 6
    t.decimal "release_temperature", precision: 15, scale: 6
    t.decimal "release_height", precision: 15, scale: 6
    t.decimal "fire_diameter", precision: 15, scale: 6
    t.decimal "fire_height", precision: 15, scale: 6
    t.decimal "fire_duration", precision: 15, scale: 6
    t.decimal "burn_rate", precision: 15, scale: 6
    t.decimal "surface_emissive_power", precision: 15, scale: 6
    t.decimal "radiative_fraction", precision: 15, scale: 6
    t.decimal "flame_temperature", precision: 15, scale: 6
    t.decimal "transmissivity", precision: 15, scale: 6
    t.decimal "ambient_temperature", precision: 15, scale: 6
    t.decimal "ambient_pressure", precision: 15, scale: 6
    t.decimal "wind_speed", precision: 15, scale: 6
    t.decimal "wind_direction", precision: 15, scale: 6
    t.decimal "relative_humidity", precision: 15, scale: 6
    t.decimal "view_factor_method"
    t.decimal "atmospheric_absorption_coefficient", precision: 15, scale: 6
    t.decimal "maximum_heat_flux", precision: 15, scale: 6
    t.decimal "maximum_range", precision: 15, scale: 6
    t.integer "calculation_resolution", default: 50
    t.integer "calculation_sectors", default: 36
    t.decimal "max_calculation_distance", precision: 15, scale: 6, default: "2000.0"
    t.string "calculation_status", default: "pending"
    t.text "calculation_warnings"
    t.datetime "last_calculated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculation_status"], name: "idx_thermal_incidents_status"
    t.index ["dispersion_scenario_id"], name: "idx_thermal_incidents_scenario"
    t.index ["fire_diameter", "fire_duration"], name: "idx_thermal_incidents_fire_params"
    t.index ["incident_type"], name: "idx_thermal_incidents_type"
  end

  create_table "thermal_zones", force: :cascade do |t|
    t.bigint "thermal_radiation_incident_id", null: false
    t.decimal "heat_flux_threshold", precision: 15, scale: 6, null: false
    t.string "zone_type", null: false
    t.text "zone_description"
    t.decimal "max_radius", precision: 15, scale: 6, null: false
    t.decimal "min_radius", precision: 15, scale: 6, default: "0.0"
    t.decimal "zone_area", precision: 15, scale: 6
    t.decimal "zone_area_km2", precision: 15, scale: 6
    t.decimal "zone_perimeter", precision: 15, scale: 6
    t.integer "estimated_population_affected", default: 0
    t.integer "estimated_casualties", default: 0
    t.integer "buildings_at_risk", default: 0
    t.boolean "evacuation_required", default: false
    t.decimal "evacuation_radius", precision: 15, scale: 6
    t.boolean "emergency_response_required", default: false
    t.boolean "fire_suppression_required", default: false
    t.boolean "medical_response_required", default: false
    t.text "protective_actions"
    t.text "zone_boundary_coordinates"
    t.text "overlapping_zones"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evacuation_required"], name: "idx_thermal_zones_evacuation"
    t.index ["heat_flux_threshold"], name: "idx_thermal_zones_threshold"
    t.index ["max_radius", "zone_area"], name: "idx_thermal_zones_geometry"
    t.index ["thermal_radiation_incident_id"], name: "idx_thermal_zones_incident"
    t.index ["zone_type"], name: "idx_thermal_zones_type"
  end

  create_table "toxicological_data", force: :cascade do |t|
    t.bigint "chemical_id", null: false
    t.decimal "aegl_1_10min", precision: 10, scale: 4
    t.decimal "aegl_1_30min", precision: 10, scale: 4
    t.decimal "aegl_1_1hr", precision: 10, scale: 4
    t.decimal "aegl_1_4hr", precision: 10, scale: 4
    t.decimal "aegl_1_8hr", precision: 10, scale: 4
    t.decimal "aegl_2_10min", precision: 10, scale: 4
    t.decimal "aegl_2_30min", precision: 10, scale: 4
    t.decimal "aegl_2_1hr", precision: 10, scale: 4
    t.decimal "aegl_2_4hr", precision: 10, scale: 4
    t.decimal "aegl_2_8hr", precision: 10, scale: 4
    t.decimal "aegl_3_10min", precision: 10, scale: 4
    t.decimal "aegl_3_30min", precision: 10, scale: 4
    t.decimal "aegl_3_1hr", precision: 10, scale: 4
    t.decimal "aegl_3_4hr", precision: 10, scale: 4
    t.decimal "aegl_3_8hr", precision: 10, scale: 4
    t.decimal "erpg_1", precision: 10, scale: 4
    t.decimal "erpg_2", precision: 10, scale: 4
    t.decimal "erpg_3", precision: 10, scale: 4
    t.decimal "pac_1_10min", precision: 10, scale: 4
    t.decimal "pac_1_30min", precision: 10, scale: 4
    t.decimal "pac_1_1hr", precision: 10, scale: 4
    t.decimal "pac_1_4hr", precision: 10, scale: 4
    t.decimal "pac_1_8hr", precision: 10, scale: 4
    t.decimal "pac_2_10min", precision: 10, scale: 4
    t.decimal "pac_2_30min", precision: 10, scale: 4
    t.decimal "pac_2_1hr", precision: 10, scale: 4
    t.decimal "pac_2_4hr", precision: 10, scale: 4
    t.decimal "pac_2_8hr", precision: 10, scale: 4
    t.decimal "pac_3_10min", precision: 10, scale: 4
    t.decimal "pac_3_30min", precision: 10, scale: 4
    t.decimal "pac_3_1hr", precision: 10, scale: 4
    t.decimal "pac_3_4hr", precision: 10, scale: 4
    t.decimal "pac_3_8hr", precision: 10, scale: 4
    t.decimal "idlh", precision: 10, scale: 4
    t.decimal "pel_twa", precision: 10, scale: 4
    t.decimal "pel_stel", precision: 10, scale: 4
    t.decimal "rel_twa", precision: 10, scale: 4
    t.decimal "rel_stel", precision: 10, scale: 4
    t.decimal "tlv_twa", precision: 10, scale: 4
    t.decimal "tlv_stel", precision: 10, scale: 4
    t.string "concentration_units", default: "ppm"
    t.decimal "mg_per_m3_conversion_factor", precision: 12, scale: 4
    t.string "aegl_source"
    t.string "erpg_source"
    t.string "pac_source"
    t.string "idlh_source"
    t.text "data_notes"
    t.date "data_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chemical_id", "aegl_3_1hr"], name: "index_toxicological_data_on_chemical_id_and_aegl_3_1hr"
    t.index ["chemical_id", "erpg_3"], name: "index_toxicological_data_on_chemical_id_and_erpg_3"
    t.index ["chemical_id"], name: "index_toxicological_data_on_chemical_id"
  end

  create_table "vapor_cloud_explosions", force: :cascade do |t|
    t.bigint "dispersion_scenario_id", null: false
    t.string "explosion_type", null: false
    t.decimal "cloud_mass", precision: 12, scale: 2, null: false
    t.decimal "cloud_volume", precision: 12, scale: 2
    t.decimal "cloud_radius", precision: 8, scale: 2
    t.decimal "cloud_height", precision: 8, scale: 2
    t.decimal "cloud_concentration", precision: 15, scale: 8
    t.decimal "lower_flammability_limit", precision: 8, scale: 4, null: false
    t.decimal "upper_flammability_limit", precision: 8, scale: 4, null: false
    t.decimal "stoichiometric_concentration", precision: 8, scale: 4
    t.decimal "minimum_ignition_energy", precision: 12, scale: 8
    t.decimal "laminar_flame_speed", precision: 8, scale: 4
    t.decimal "heat_of_combustion", precision: 12, scale: 2
    t.decimal "ambient_temperature", precision: 10, scale: 2, null: false
    t.decimal "ambient_pressure", precision: 12, scale: 2, null: false
    t.decimal "relative_humidity", precision: 5, scale: 2
    t.decimal "wind_speed", precision: 8, scale: 2
    t.string "atmospheric_stability_class"
    t.decimal "ignition_delay_time", precision: 8, scale: 2
    t.decimal "ignition_probability", precision: 6, scale: 4
    t.string "ignition_source_type"
    t.decimal "ignition_location_x", precision: 10, scale: 2
    t.decimal "ignition_location_y", precision: 10, scale: 2
    t.decimal "ignition_height", precision: 8, scale: 2
    t.decimal "turbulent_flame_speed", precision: 8, scale: 4
    t.decimal "flame_acceleration_factor", precision: 8, scale: 4
    t.integer "reactivity_index"
    t.decimal "obstacle_density", precision: 6, scale: 4
    t.decimal "congestion_factor", precision: 6, scale: 4
    t.decimal "confinement_factor", precision: 6, scale: 4
    t.decimal "maximum_overpressure", precision: 12, scale: 2
    t.decimal "positive_phase_duration", precision: 8, scale: 4
    t.decimal "negative_phase_duration", precision: 8, scale: 4
    t.decimal "impulse_positive", precision: 12, scale: 4
    t.decimal "impulse_negative", precision: 12, scale: 4
    t.decimal "blast_wave_speed", precision: 10, scale: 2
    t.decimal "tnt_equivalent_mass", precision: 12, scale: 2
    t.decimal "efficiency_factor", precision: 6, scale: 4
    t.decimal "yield_factor", precision: 6, scale: 4
    t.decimal "max_calculation_distance", precision: 10, scale: 2, default: "5000.0"
    t.decimal "calculation_resolution", precision: 8, scale: 2, default: "10.0"
    t.integer "calculation_sectors", default: 36
    t.string "calculation_status", default: "pending"
    t.datetime "last_calculated_at"
    t.decimal "calculation_uncertainty", precision: 6, scale: 4
    t.text "calculation_warnings"
    t.text "model_assumptions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calculation_status"], name: "idx_explosions_status"
    t.index ["cloud_mass"], name: "idx_explosions_mass"
    t.index ["dispersion_scenario_id", "explosion_type"], name: "idx_explosions_scenario_type"
    t.index ["dispersion_scenario_id"], name: "index_vapor_cloud_explosions_on_dispersion_scenario_id"
    t.index ["maximum_overpressure"], name: "idx_explosions_pressure"
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

  create_table "weather_forecasts", force: :cascade do |t|
    t.bigint "weather_station_id", null: false
    t.bigint "dispersion_scenario_id"
    t.datetime "forecast_issued_at", null: false
    t.datetime "forecast_valid_at", null: false
    t.integer "forecast_hour", null: false
    t.string "forecast_model"
    t.decimal "forecast_confidence", precision: 4, scale: 3
    t.decimal "temperature", precision: 5, scale: 2
    t.decimal "temperature_min", precision: 5, scale: 2
    t.decimal "temperature_max", precision: 5, scale: 2
    t.decimal "wind_speed", precision: 5, scale: 2
    t.decimal "wind_direction", precision: 5, scale: 2
    t.decimal "wind_gust_speed", precision: 5, scale: 2
    t.string "predicted_stability_class", limit: 1
    t.decimal "predicted_mixing_height", precision: 8, scale: 2
    t.integer "cloud_cover_forecast"
    t.decimal "precipitation_probability", precision: 4, scale: 2
    t.decimal "precipitation_amount", precision: 6, scale: 3
    t.json "hourly_temperature"
    t.json "hourly_wind_speed"
    t.json "hourly_wind_direction"
    t.json "hourly_stability_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_scenario_id", "forecast_valid_at"], name: "index_weather_forecasts_on_scenario_valid"
    t.index ["dispersion_scenario_id"], name: "index_weather_forecasts_on_dispersion_scenario_id"
    t.index ["forecast_valid_at", "forecast_hour"], name: "index_weather_forecasts_on_valid_hour"
    t.index ["weather_station_id", "forecast_valid_at"], name: "index_weather_forecasts_on_station_valid"
    t.index ["weather_station_id"], name: "index_weather_forecasts_on_weather_station_id"
  end

  create_table "weather_observations", force: :cascade do |t|
    t.bigint "weather_station_id", null: false
    t.bigint "dispersion_scenario_id"
    t.datetime "observed_at", null: false
    t.string "observation_type", null: false
    t.integer "forecast_hour"
    t.string "data_source", null: false
    t.decimal "data_confidence", precision: 4, scale: 3
    t.decimal "temperature", precision: 5, scale: 2
    t.decimal "temperature_dewpoint", precision: 5, scale: 2
    t.decimal "relative_humidity", precision: 5, scale: 2
    t.decimal "pressure_station", precision: 7, scale: 2
    t.decimal "pressure_sea_level", precision: 7, scale: 2
    t.decimal "wind_speed", precision: 5, scale: 2
    t.decimal "wind_direction", precision: 5, scale: 2
    t.decimal "wind_gust_speed", precision: 5, scale: 2
    t.decimal "wind_speed_10m", precision: 5, scale: 2
    t.string "pasquill_stability_class", limit: 1
    t.decimal "richardson_number", precision: 8, scale: 5
    t.decimal "monin_obukhov_length", precision: 10, scale: 3
    t.decimal "friction_velocity", precision: 6, scale: 4
    t.decimal "sensible_heat_flux", precision: 8, scale: 3
    t.decimal "solar_radiation", precision: 7, scale: 2
    t.decimal "net_radiation", precision: 7, scale: 2
    t.integer "cloud_cover_total"
    t.integer "cloud_cover_low"
    t.decimal "cloud_base_height", precision: 8, scale: 2
    t.string "weather_condition"
    t.decimal "precipitation_rate", precision: 6, scale: 3
    t.decimal "precipitation_1hr", precision: 6, scale: 3
    t.decimal "precipitation_24hr", precision: 6, scale: 3
    t.decimal "visibility", precision: 8, scale: 2
    t.decimal "mixing_height", precision: 8, scale: 2
    t.decimal "inversion_height", precision: 8, scale: 2
    t.boolean "inversion_present", default: false
    t.decimal "turbulence_intensity", precision: 5, scale: 4
    t.decimal "sigma_theta", precision: 5, scale: 3
    t.decimal "sigma_phi", precision: 5, scale: 3
    t.json "quality_flags"
    t.json "raw_data"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispersion_scenario_id", "observed_at"], name: "index_weather_observations_on_scenario_time"
    t.index ["dispersion_scenario_id"], name: "index_weather_observations_on_dispersion_scenario_id"
    t.index ["observed_at", "observation_type"], name: "index_weather_observations_on_time_type"
    t.index ["pasquill_stability_class", "observed_at"], name: "index_weather_observations_on_stability_time"
    t.index ["weather_station_id", "observed_at"], name: "index_weather_observations_on_station_time"
    t.index ["weather_station_id"], name: "index_weather_observations_on_weather_station_id"
  end

  create_table "weather_stations", force: :cascade do |t|
    t.string "station_id", null: false
    t.string "name", null: false
    t.string "station_type", null: false
    t.string "data_source", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.decimal "elevation", precision: 8, scale: 2
    t.string "country_code", limit: 2
    t.string "state_code", limit: 3
    t.string "timezone"
    t.json "contact_info"
    t.boolean "active", default: true
    t.integer "data_quality_rating"
    t.decimal "coverage_radius", precision: 8, scale: 2
    t.datetime "last_observation_at"
    t.datetime "established_at"
    t.json "api_config"
    t.json "data_processing_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "station_type"], name: "index_weather_stations_on_active_type"
    t.index ["data_source", "last_observation_at"], name: "index_weather_stations_on_source_observation"
    t.index ["latitude", "longitude"], name: "index_weather_stations_on_coordinates"
    t.index ["station_id"], name: "index_weather_stations_on_station_id", unique: true
  end

  add_foreign_key "atmospheric_dispersions", "dispersion_scenarios"
  add_foreign_key "atmospheric_profiles", "weather_observations"
  add_foreign_key "blast_calculations", "vapor_cloud_explosions"
  add_foreign_key "buildings", "map_layers"
  add_foreign_key "chemical_solutions", "chemicals"
  add_foreign_key "concentration_contours", "atmospheric_dispersions"
  add_foreign_key "dispersion_calculations", "dispersion_events"
  add_foreign_key "dispersion_calculations", "weather_data"
  add_foreign_key "dispersion_events", "chemicals"
  add_foreign_key "dispersion_events", "locations"
  add_foreign_key "dispersion_scenarios", "chemicals"
  add_foreign_key "equipment_thermal_damages", "buildings"
  add_foreign_key "equipment_thermal_damages", "thermal_radiation_incidents"
  add_foreign_key "explosion_zones", "vapor_cloud_explosions"
  add_foreign_key "gis_features", "map_layers"
  add_foreign_key "location_weather_cache", "weather_stations", column: "primary_weather_station_id"
  add_foreign_key "location_weather_cache", "weather_stations", column: "secondary_weather_station_id"
  add_foreign_key "location_weather_cache", "weather_stations", column: "tertiary_weather_station_id"
  add_foreign_key "plume_calculations", "atmospheric_dispersions"
  add_foreign_key "receptor_calculations", "atmospheric_dispersions"
  add_foreign_key "receptor_calculations", "receptors"
  add_foreign_key "receptors", "dispersion_events"
  add_foreign_key "release_calculations", "dispersion_scenarios"
  add_foreign_key "source_details", "dispersion_scenarios"
  add_foreign_key "structural_damages", "buildings"
  add_foreign_key "structural_damages", "vapor_cloud_explosions"
  add_foreign_key "terrain_points", "map_layers"
  add_foreign_key "thermal_calculations", "thermal_radiation_incidents"
  add_foreign_key "thermal_radiation_incidents", "dispersion_scenarios"
  add_foreign_key "thermal_zones", "thermal_radiation_incidents"
  add_foreign_key "toxicological_data", "chemicals"
  add_foreign_key "vapor_cloud_explosions", "dispersion_scenarios"
  add_foreign_key "weather_forecasts", "dispersion_scenarios"
  add_foreign_key "weather_forecasts", "weather_stations"
  add_foreign_key "weather_observations", "dispersion_scenarios"
  add_foreign_key "weather_observations", "weather_stations"
end
