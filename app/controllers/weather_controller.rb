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
  # Get current weather conditions for specific coordinates
  def current
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      weather_data = WeatherService.fetch_weather_data(latitude, longitude)
      stability_class = WeatherService.calculate_stability_class(weather_data)
      
      response_data = weather_data.merge(
        stability_class: stability_class,
        coordinates: [latitude, longitude]
      )
      
      respond_to do |format|
        format.json { render json: response_data }
        format.html { 
          @weather_data = response_data
          render 'current'
        }
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :service_unavailable }
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
      forecast_data = WeatherService.fetch_forecast_data(latitude, longitude, hours)
      
      # Add stability classes to each forecast period
      forecast_with_stability = forecast_data.map do |forecast|
        stability_class = WeatherService.calculate_stability_class(forecast)
        forecast.merge(stability_class: stability_class)
      end
      
      respond_to do |format|
        format.json { render json: forecast_with_stability }
        format.html { 
          @forecast_data = forecast_with_stability
          @coordinates = [latitude, longitude]
          render 'forecast'
        }
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :service_unavailable }
        format.html { 
          flash[:error] = "Unable to fetch forecast data: #{e.message}"
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