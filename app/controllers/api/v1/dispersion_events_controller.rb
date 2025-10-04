class Api::V1::DispersionEventsController < Api::V1::BaseController
  before_action :set_dispersion_event, only: [:show, :update, :live_calculations, :plume_data]

  def index
    @dispersion_events = DispersionEvent.includes(:chemical, :location)
                                       .order(created_at: :desc)
                                       .limit(50)
    
    render_success(@dispersion_events.map { |event| dispersion_event_data(event) })
  end

  def show
    render_success({
      event: dispersion_event_data(@dispersion_event),
      receptors: @dispersion_event.receptors.map { |r| receptor_data(r) },
      latest_calculations: @dispersion_event.dispersion_calculations
                                          .includes(:weather_datum)
                                          .order(created_at: :desc)
                                          .limit(10)
                                          .map { |c| calculation_data(c) }
    })
  end

  def create
    @dispersion_event = DispersionEvent.new(dispersion_event_params)
    
    if @dispersion_event.save
      render_success(dispersion_event_data(@dispersion_event), 'Dispersion event created successfully')
    else
      render_error(@dispersion_event.errors.full_messages.join(', '))
    end
  end

  def update
    if @dispersion_event.update(dispersion_event_params)
      render_success(dispersion_event_data(@dispersion_event), 'Dispersion event updated successfully')
    else
      render_error(@dispersion_event.errors.full_messages.join(', '))
    end
  end

  def live_calculations
    # Return real-time calculation data for WebSocket updates
    calculations = @dispersion_event.dispersion_calculations
                                   .includes(:weather_datum)
                                   .where('created_at > ?', 1.minute.ago)
                                   .order(created_at: :desc)

    render_success({
      event_id: @dispersion_event.id,
      calculations: calculations.map { |c| calculation_data(c) },
      timestamp: Time.current
    })
  end

  def plume_data
    # Generate plume contour data for map visualization
    latest_calculation = @dispersion_event.dispersion_calculations
                                         .includes(:weather_datum)
                                         .order(created_at: :desc)
                                         .first

    if latest_calculation
      # Generate contour data using the existing plume_contours method
      contour_data = latest_calculation.plume_contours
      
      render_success({
        event_id: @dispersion_event.id,
        source_location: {
          lat: @dispersion_event.location.latitude,
          lng: @dispersion_event.location.longitude
        },
        contours: contour_data,
        weather: weather_data(latest_calculation.weather_datum),
        timestamp: latest_calculation.created_at
      })
    else
      # Generate basic contour even without calculations
      render_success({
        event_id: @dispersion_event.id,
        source_location: {
          lat: @dispersion_event.location.latitude,
          lng: @dispersion_event.location.longitude
        },
        contours: default_plume_contours,
        weather: nil,
        timestamp: Time.current
      })
    end
  end

  private

  def set_dispersion_event
    @dispersion_event = DispersionEvent.find(params[:id])
  end

  def dispersion_event_params
    params.require(:dispersion_event).permit(:chemical_id, :location_id, :release_rate, 
                                           :release_duration, :release_height, 
                                           :release_temperature, :wind_speed, 
                                           :atmospheric_stability, :start_time, 
                                           :end_time, :status, :description)
  end

  def dispersion_event_data(event)
    {
      id: event.id,
      chemical: event.chemical.name,
      location: event.location.name,
      release_rate: event.release_rate,
      status: event.status,
      start_time: event.started_at,
      source_coordinates: {
        lat: event.location.latitude,
        lng: event.location.longitude
      }
    }
  end

  def receptor_data(receptor)
    latest_calc = receptor.dispersion_calculations.order(created_at: :desc).first
    {
      id: receptor.id,
      name: receptor.name,
      coordinates: {
        lat: receptor.latitude,
        lng: receptor.longitude
      },
      height: receptor.height,
      latest_concentration: latest_calc&.concentration || 0,
      health_impact: receptor.assess_health_impact(latest_calc&.concentration || 0)
    }
  end

  def calculation_data(calculation)
    {
      id: calculation.id,
      concentration: calculation.concentration,
      receptor_coordinates: {
        lat: calculation.receptor_latitude,
        lng: calculation.receptor_longitude
      },
      weather_conditions: weather_data(calculation.weather_datum),
      timestamp: calculation.created_at
    }
  end

  def weather_data(weather)
    return nil unless weather
    
    {
      wind_speed: weather.wind_speed,
      wind_direction: weather.wind_direction,
      temperature: weather.temperature,
      stability_class: weather.stability_class,
      timestamp: weather.recorded_at
    }
  end

  def default_plume_contours
    # Return default circular contours when no calculation data is available
    source_lat = @dispersion_event.location.latitude
    source_lng = @dispersion_event.location.longitude
    
    [
      {
        concentration: 10.0,
        coordinates: generate_circle_coordinates(source_lat, source_lng, 0.001),
        color: '#ff0000',
        level: 'high'
      },
      {
        concentration: 1.0,
        coordinates: generate_circle_coordinates(source_lat, source_lng, 0.005),
        color: '#ff7f00',
        level: 'medium'
      },
      {
        concentration: 0.1,
        coordinates: generate_circle_coordinates(source_lat, source_lng, 0.01),
        color: '#ffff00',
        level: 'low'
      }
    ]
  end

  def generate_circle_coordinates(center_lat, center_lng, radius, points = 32)
    coordinates = []
    (0...points).each do |i|
      angle = 2 * Math::PI * i / points
      lat = center_lat + radius * Math.cos(angle)
      lng = center_lng + radius * Math.sin(angle)
      coordinates << [lat, lng]
    end
    coordinates << coordinates.first # Close the polygon
    coordinates
  end
end