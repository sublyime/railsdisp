class WeatherDataController < ApplicationController
  before_action :set_weather_datum, only: [:show, :edit, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:update_all, :update_location, :current, :forecast]

  def index
    @weather_data = WeatherDatum.all.order(timestamp: :desc).limit(50)
  end

  def show
  end

  def new
    @weather_datum = WeatherDatum.new
  end

  def create
    @weather_datum = WeatherDatum.new(weather_datum_params)
    
    if @weather_datum.save
      redirect_to @weather_datum, notice: 'Weather data was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @weather_datum.update(weather_datum_params)
      redirect_to @weather_datum, notice: 'Weather data was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @weather_datum.destroy
    redirect_to weather_data_url, notice: 'Weather data was successfully deleted.'
  end

  # API endpoint for updating all location weather data
  def update_all
    begin
      # Trigger weather update job for all locations
      WeatherUpdateJob.perform_later
      
      render json: {
        status: 'success',
        message: 'Weather update initiated for all locations'
      }
    rescue => e
      render json: {
        status: 'error',
        message: e.message
      }, status: 500
    end
  end

  # API endpoint for updating specific location weather
  def update_location
    location_id = params[:location_id]
    
    begin
      if location_id
        location = Location.find(location_id)
        WeatherUpdateJob.perform_later(location_id)
        
        render json: {
          status: 'success',
          message: "Weather update initiated for #{location.name}"
        }
      else
        render json: {
          status: 'error',
          message: 'Location ID required'
        }, status: 400
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        status: 'error',
        message: 'Location not found'
      }, status: 404
    rescue => e
      render json: {
        status: 'error',
        message: e.message
      }, status: 500
    end
  end

  # API endpoint for current weather at coordinates
  def current
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      weather_service = WeatherService.new
      weather_data = weather_service.get_current_weather(latitude, longitude)
      
      render json: {
        status: 'success',
        data: weather_data
      }
    rescue => e
      render json: {
        status: 'error',
        message: e.message
      }, status: 500
    end
  end

  # API endpoint for weather forecast
  def forecast
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    hours = params[:hours]&.to_i || 24
    
    begin
      weather_service = WeatherService.new
      forecast_data = weather_service.get_forecast(latitude, longitude, hours)
      
      render json: {
        status: 'success',
        data: forecast_data
      }
    rescue => e
      render json: {
        status: 'error',
        message: e.message
      }, status: 500
    end
  end

  private

  def set_weather_datum
    @weather_datum = WeatherDatum.find(params[:id])
  end

  def weather_datum_params
    params.require(:weather_datum).permit(:timestamp, :wind_speed, :wind_direction, 
                                        :temperature, :humidity, :pressure, 
                                        :stability_class, :mixing_height, 
                                        :precipitation, :cloud_cover)
  end
end
