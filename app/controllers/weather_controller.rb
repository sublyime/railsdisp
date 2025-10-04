# Weather Controller for API endpoints and weather data management

class WeatherController < ApplicationController
  before_action :set_weather_datum, only: [:show, :update, :destroy]
  
  # GET /weather
  # Get weather data for all locations or filter by coordinates
  def index
    @weather_data = WeatherDatum.includes(:dispersion_calculations)
    
    if params[:latitude] && params[:longitude]
      radius = params[:radius]&.to_f || 0.1
      @weather_data = @weather_data.by_location(
        params[:latitude].to_f, 
        params[:longitude].to_f, 
        radius
      )
    end
    
    if params[:recent]
      @weather_data = @weather_data.recent
    end
    
    @weather_data = @weather_data.order(recorded_at: :desc)
                                 .limit(params[:limit]&.to_i || 100)
    
    respond_to do |format|
      format.html
      format.json { render json: weather_data_json }
    end
  end

  # GET /weather/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: @weather_datum.as_json(include_calculations: true) }
    end
  end

  # POST /weather
  # Create new weather record (for manual entry or external integration)
  def create
    @weather_datum = WeatherDatum.new(weather_params)
    
    if @weather_datum.save
      # Calculate stability class
      stability = WeatherService.calculate_stability_class(
        temperature: @weather_datum.temperature,
        wind_speed: @weather_datum.wind_speed,
        cloud_cover: @weather_datum.cloud_cover,
        timestamp: @weather_datum.recorded_at
      )
      @weather_datum.update(atmospheric_stability: stability)
      
      # Broadcast update
      broadcast_weather_update
      
      respond_to do |format|
        format.html { redirect_to @weather_datum, notice: 'Weather data was successfully created.' }
        format.json { render json: @weather_datum, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.json { render json: @weather_datum.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /weather/:id
  def update
    if @weather_datum.update(weather_params)
      broadcast_weather_update
      
      respond_to do |format|
        format.html { redirect_to @weather_datum, notice: 'Weather data was successfully updated.' }
        format.json { render json: @weather_datum }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: @weather_datum.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /weather/:id
  def destroy
    @weather_datum.destroy
    
    respond_to do |format|
      format.html { redirect_to weather_index_url, notice: 'Weather data was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  # POST /weather/update_all
  # Trigger weather update for all locations
  def update_all
    WeatherUpdateJob.perform_later
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: weather_index_path, notice: 'Weather update initiated for all locations.') }
      format.json { render json: { message: 'Weather update initiated', status: 'queued' } }
    end
  end

  # POST /weather/update_location
  # Trigger weather update for specific location
  def update_location
    location_id = params[:location_id]
    
    if location_id.present?
      WeatherUpdateJob.perform_later(location_id)
      message = "Weather update initiated for location #{location_id}"
    else
      message = "Location ID required"
      status = :bad_request
    end
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: weather_index_path, notice: message) }
      format.json { render json: { message: message }, status: status || :ok }
    end
  end

  # GET /weather/current/:latitude/:longitude
  # Get current weather conditions for specific coordinates using comprehensive WeatherService
  def current
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      weather_service = WeatherService.new(latitude: latitude, longitude: longitude)
      weather_data = weather_service.get_weather_for_location(latitude, longitude)
      
      if weather_data
        response_data = {
          weather_data: weather_data,
          coordinates: [latitude, longitude],
          fetched_at: Time.current,
          status: 'success'
        }
      else
        response_data = {
          error: 'No weather data available for this location',
          coordinates: [latitude, longitude],
          status: 'no_data'
        }
      end
      
      respond_to do |format|
        format.json { render json: response_data }
        format.html { 
          @weather_data = response_data[:weather_data]
          @coordinates = [latitude, longitude]
          render 'current'
        }
      end
    rescue => e
      Rails.logger.error "Weather fetch error for #{latitude}, #{longitude}: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: e.message, coordinates: [latitude, longitude], status: 'error' }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to fetch weather data: #{e.message}"
          redirect_to weather_index_path
        }
      end
    end
  end

  # GET /weather/forecast/:latitude/:longitude
  # Get weather forecast for specific coordinates
  def forecast
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    hours = params[:hours]&.to_i || 24
    
    begin
      weather_service = WeatherService.new(latitude: latitude, longitude: longitude)
      forecast_data = weather_service.fetch_forecast_data(latitude, longitude)
      
      response_data = {
        forecast_data: forecast_data,
        coordinates: [latitude, longitude],
        hours_requested: hours,
        fetched_at: Time.current,
        status: 'success'
      }
      
      respond_to do |format|
        format.json { render json: response_data }
        format.html { 
          @forecast_data = forecast_data
          @coordinates = [latitude, longitude]
          render 'forecast'
        }
      end
    rescue => e
      Rails.logger.error "Forecast fetch error for #{latitude}, #{longitude}: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: e.message, coordinates: [latitude, longitude], status: 'error' }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to fetch forecast data: #{e.message}"
          redirect_to weather_index_path
        }
      end
    end
  end

  # POST /weather/for_dispersion
  # Get weather data specifically for a dispersion scenario
  def for_dispersion
    scenario_id = params[:scenario_id]
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      # Find or create dispersion scenario
      scenario = if scenario_id.present?
                  DispersionScenario.find(scenario_id)
                else
                  DispersionScenario.new(latitude: latitude, longitude: longitude)
                end
      
      weather_service = WeatherService.new(latitude: latitude, longitude: longitude)
      dispersion_weather = weather_service.get_weather_for_dispersion(scenario)
      
      if dispersion_weather
        response_data = {
          dispersion_weather: dispersion_weather,
          scenario_id: scenario.id,
          status: 'success'
        }
      else
        response_data = {
          error: 'No weather data available for dispersion modeling',
          scenario_id: scenario.id,
          status: 'no_data'
        }
      end
      
      respond_to do |format|
        format.json { render json: response_data }
        format.html { redirect_to dispersion_scenario_path(scenario) }
      end
    rescue => e
      Rails.logger.error "Dispersion weather fetch error: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: e.message, status: 'error' }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to fetch weather data for dispersion: #{e.message}"
          redirect_to weather_index_path
        }
      end
    end
  end

  # GET /weather/stations_near/:latitude/:longitude
  # Get weather stations near specified coordinates
  def stations_near
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    radius_km = params[:radius]&.to_f || 50.0
    
    begin
      weather_service = WeatherService.new(latitude: latitude, longitude: longitude)
      stations = weather_service.find_or_create_weather_stations(latitude, longitude, radius_km)
      
      stations_data = stations.map do |station|
        {
          id: station.id,
          station_id: station.station_id,
          name: station.name,
          station_type: station.station_type,
          coordinates: [station.latitude, station.longitude],
          distance_km: station.distance_to_point(latitude, longitude),
          data_source: station.data_source,
          active: station.active,
          last_observation: station.last_observation_at,
          has_recent_data: station.has_recent_data?
        }
      end
      
      respond_to do |format|
        format.json { render json: { stations: stations_data, search_location: [latitude, longitude], radius_km: radius_km } }
        format.html { 
          @stations = stations_data
          @search_location = [latitude, longitude]
          render 'stations_near'
        }
      end
    rescue => e
      Rails.logger.error "Weather stations search error: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to search weather stations: #{e.message}"
          redirect_to weather_index_path
        }
      end
    end
  end

  # GET /weather/atmospheric_stability/:latitude/:longitude
  # Get detailed atmospheric stability analysis for location
  def atmospheric_stability
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      weather_service = WeatherService.new(latitude: latitude, longitude: longitude)
      weather_data = weather_service.get_weather_for_location(latitude, longitude)
      
      if weather_data
        stability_analysis = weather_service.calculate_stability_for_dispersion(weather_data)
        dispersion_params = weather_service.generate_dispersion_parameters(weather_data)
        
        response_data = {
          stability_analysis: stability_analysis,
          dispersion_parameters: dispersion_params,
          weather_conditions: weather_data,
          coordinates: [latitude, longitude],
          status: 'success'
        }
      else
        response_data = {
          error: 'No weather data available for stability analysis',
          coordinates: [latitude, longitude],
          status: 'no_data'
        }
      end
      
      respond_to do |format|
        format.json { render json: response_data }
        format.html { 
          @stability_data = response_data
          @coordinates = [latitude, longitude]
          render 'atmospheric_stability'
        }
      end
    rescue => e
      Rails.logger.error "Atmospheric stability analysis error: #{e.message}"
      respond_to do |format|
        format.json { render json: { error: e.message, status: 'error' }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to analyze atmospheric stability: #{e.message}"
          redirect_to weather_index_path
        }
      end
    end
  end

  private

  def set_weather_datum
    @weather_datum = WeatherDatum.find(params[:id])
  end

  def weather_params
    params.require(:weather_datum).permit(
      :recorded_at, :temperature, :humidity, :pressure, :wind_speed, 
      :wind_direction, :precipitation, :cloud_cover, :visibility,
      :latitude, :longitude, :source
    )
  end

  def weather_data_json
    @weather_data.map do |weather|
      weather.as_json.merge(
        stability_class: weather.stability_class,
        wind_vector: weather.wind_vector,
        coordinates: weather.coordinates
      )
    end
  end

  def broadcast_weather_update
    ActionCable.server.broadcast(
      "weather_channel",
      {
        weather_data: @weather_datum.as_json,
        stability_class: @weather_datum.stability_class,
        coordinates: @weather_datum.coordinates
      }
    )
  end
end