class WeatherDataController < ApplicationController
  before_action :set_weather_datum, only: [:show, :edit, :update, :destroy]

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
