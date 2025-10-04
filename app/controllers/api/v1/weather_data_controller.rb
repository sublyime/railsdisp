class Api::V1::WeatherDataController < Api::V1::BaseController
  def index
    @weather_data = WeatherDatum.order(timestamp: :desc).limit(50)
    
    render_success({
      weather_data: @weather_data.map { |w| weather_data_json(w) },
      count: @weather_data.count
    })
  end

  def create
    @weather_datum = WeatherDatum.new(weather_datum_params)
    
    if @weather_datum.save
      # Broadcast new weather data to active dispersion events
      ActionCable.server.broadcast('weather_updates', {
        type: 'new_weather_data',
        data: weather_data_json(@weather_datum)
      })
      
      render_success(weather_data_json(@weather_datum), 'Weather data created successfully')
    else
      render_error(@weather_datum.errors.full_messages.join(', '))
    end
  end

  def update
    @weather_datum = WeatherDatum.find(params[:id])
    
    if @weather_datum.update(weather_datum_params)
      render_success(weather_data_json(@weather_datum), 'Weather data updated successfully')
    else
      render_error(@weather_datum.errors.full_messages.join(', '))
    end
  end

  private

  def weather_datum_params
    params.require(:weather_datum).permit(:timestamp, :wind_speed, :wind_direction, 
                                        :temperature, :humidity, :pressure, 
                                        :stability_class, :mixing_height, 
                                        :precipitation, :cloud_cover)
  end

  def weather_data_json(weather)
    {
      id: weather.id,
      timestamp: weather.timestamp,
      wind_speed: weather.wind_speed,
      wind_direction: weather.wind_direction,
      temperature: weather.temperature,
      humidity: weather.humidity,
      pressure: weather.pressure,
      stability_class: weather.stability_class,
      mixing_height: weather.mixing_height,
      precipitation: weather.precipitation,
      cloud_cover: weather.cloud_cover
    }
  end
end