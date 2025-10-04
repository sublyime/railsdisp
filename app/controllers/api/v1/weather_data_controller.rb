# API Controller for Weather data endpoints

class Api::V1::WeatherDataController < Api::V1::BaseController
  before_action :set_weather_datum, only: [:show, :update, :destroy]
  
  # GET /api/v1/weather_data
  def index
    @weather_data = WeatherDatum.includes(:dispersion_calculations)
    
    # Filter by location if provided
    if params[:latitude] && params[:longitude]
      radius = params[:radius]&.to_f || 0.1
      @weather_data = @weather_data.by_location(
        params[:latitude].to_f, 
        params[:longitude].to_f, 
        radius
      )
    end
    
    # Filter by time range
    if params[:recent]
      @weather_data = @weather_data.recent
    elsif params[:start_time] && params[:end_time]
      start_time = Time.parse(params[:start_time])
      end_time = Time.parse(params[:end_time])
      @weather_data = @weather_data.where(recorded_at: start_time..end_time)
    end
    
    @weather_data = @weather_data.order(recorded_at: :desc)
                                 .limit(params[:limit]&.to_i || 100)
    
    render_success({
      weather_data: weather_data_with_calculations,
      total_count: @weather_data.count,
      page_info: pagination_info
    })
  end

  # GET /api/v1/weather_data/:id
  def show
    render_success({
      weather_data: weather_datum_json(@weather_datum),
      related_calculations: @weather_datum.dispersion_calculations.count
    })
  end

  # POST /api/v1/weather_data
  def create
    @weather_datum = WeatherDatum.new(weather_datum_params)
    
    if @weather_datum.save
      # Calculate and set atmospheric stability
      stability = calculate_stability_for_weather_datum(@weather_datum)
      @weather_datum.update(atmospheric_stability: stability)
      
      # Broadcast real-time update
      broadcast_weather_update(@weather_datum)
      
      render_success({
        weather_data: weather_datum_json(@weather_datum),
        message: 'Weather data created successfully'
      })
    else
      render_error(@weather_datum.errors.full_messages.join(', '))
    end
  end

  # PATCH/PUT /api/v1/weather_data/:id
  def update
    if @weather_datum.update(weather_datum_params)
      # Recalculate stability class if relevant fields changed
      if stability_affecting_fields_changed?
        stability = calculate_stability_for_weather_datum(@weather_datum)
        @weather_datum.update(atmospheric_stability: stability)
      end
      
      broadcast_weather_update(@weather_datum)
      
      render_success({
        weather_data: weather_datum_json(@weather_datum),
        message: 'Weather data updated successfully'
      })
    else
      render_error(@weather_datum.errors.full_messages.join(', '))
    end
  end

  # GET /api/v1/weather_data/current/:latitude/:longitude
  def current
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    
    begin
      # Try to get recent local data first
      local_weather = WeatherDatum.by_location(latitude, longitude, 0.05)
                                  .where('recorded_at >= ?', 30.minutes.ago)
                                  .order(:recorded_at)
                                  .last
      
      if local_weather
        render_success({
          weather_data: weather_datum_json(local_weather),
          source: 'local_cache',
          age_minutes: ((Time.current - local_weather.recorded_at) / 60).round
        })
      else
        # Fetch from external API
        weather_data = WeatherService.fetch_weather_data(latitude, longitude)
        stability_class = WeatherService.calculate_stability_class(weather_data)
        
        render_success({
          weather_data: weather_data.merge(
            stability_class: stability_class,
            coordinates: [latitude, longitude]
          ),
          source: 'live_api',
          age_minutes: 0
        })
      end
    rescue => e
      render_error("Unable to fetch current weather data: #{e.message}")
    end
  end

  # GET /api/v1/weather_data/forecast/:latitude/:longitude
  def forecast
    latitude = params[:latitude].to_f
    longitude = params[:longitude].to_f
    hours = params[:hours]&.to_i || 24
    
    begin
      forecast_data = WeatherService.fetch_forecast_data(latitude, longitude, hours)
      
      # Add stability classes and format for API response
      forecast_with_metadata = forecast_data.map.with_index do |forecast, index|
        stability_class = WeatherService.calculate_stability_class(forecast)
        forecast.merge(
          stability_class: stability_class,
          hours_from_now: index * 3, # Assuming 3-hour intervals
          coordinates: [latitude, longitude]
        )
      end
      
      render_success({
        forecast_data: forecast_with_metadata,
        location: [latitude, longitude],
        forecast_hours: hours,
        generated_at: Time.current.iso8601
      })
    rescue => e
      render_error("Unable to fetch forecast data: #{e.message}")
    end
  end

  private

  def set_weather_datum
    @weather_datum = WeatherDatum.find(params[:id])
  end

  def weather_datum_params
    params.require(:weather_datum).permit(
      :recorded_at, :temperature, :humidity, :pressure, :wind_speed, 
      :wind_direction, :precipitation, :cloud_cover, :visibility,
      :latitude, :longitude, :source
    )
  end

  def weather_data_with_calculations
    @weather_data.map { |weather| weather_datum_json(weather) }
  end

  def weather_datum_json(weather_datum)
    weather_datum.as_json.merge(
      stability_class: weather_datum.stability_class,
      wind_vector: weather_datum.wind_vector,
      coordinates: weather_datum.coordinates,
      age_minutes: ((Time.current - weather_datum.recorded_at) / 60).round,
      daytime: weather_datum.send(:daytime?)
    )
  end

  def calculate_stability_for_weather_datum(weather_datum)
    WeatherService.calculate_stability_class(
      temperature: weather_datum.temperature,
      wind_speed: weather_datum.wind_speed,
      cloud_cover: weather_datum.cloud_cover,
      timestamp: weather_datum.recorded_at
    )
  end

  def stability_affecting_fields_changed?
    @weather_datum.previous_changes.keys.intersect?(
      %w[wind_speed cloud_cover recorded_at]
    )
  end

  def broadcast_weather_update(weather_datum)
    ActionCable.server.broadcast(
      "weather_channel",
      {
        weather_data: weather_datum_json(weather_datum),
        coordinates: weather_datum.coordinates,
        update_type: 'weather_update'
      }
    )
    
    # Also broadcast to location-specific channel if applicable
    location = Location.find_by(
      latitude: weather_datum.latitude,
      longitude: weather_datum.longitude
    )
    
    if location
      ActionCable.server.broadcast(
        "weather_location_#{location.id}",
        {
          location_id: location.id,
          weather_data: weather_datum_json(weather_datum),
          update_type: 'location_weather_update'
        }
      )
    end
  end

  def pagination_info
    {
      current_page: params[:page]&.to_i || 1,
      per_page: params[:limit]&.to_i || 100,
      has_more: @weather_data.count >= (params[:limit]&.to_i || 100)
    }
  end
end