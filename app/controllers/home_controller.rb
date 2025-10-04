class HomeController < ApplicationController
  def index
    # Main landing page
    @recent_events = DispersionEvent.includes(:chemical, :location)
                                   .order(created_at: :desc)
                                   .limit(5)
    @active_events = DispersionEvent.where(status: 'active')
                                   .includes(:chemical, :location)
    @total_chemicals = Chemical.count
    @total_locations = Location.count
  end

  def dashboard
    # Main operational dashboard
    @active_events = DispersionEvent.where(status: 'active')
                                   .includes(:chemical, :location, :receptors, :dispersion_calculations)
    
    @recent_calculations = DispersionCalculation.includes(:dispersion_event, :weather_datum)
                                               .order(created_at: :desc)
                                               .limit(10)
    
    @current_weather = WeatherDatum.order(timestamp: :desc).first
    
    # Statistics for dashboard widgets
    @stats = {
      total_events: DispersionEvent.count,
      active_events: @active_events.count,
      total_receptors: Receptor.count,
      calculations_today: DispersionCalculation.where('created_at >= ?', Date.current).count
    }
    
    # Prepare data for real-time updates
    @events_data = @active_events.map do |event|
      {
        id: event.id,
        name: "#{event.chemical.name} at #{event.location.name}",
        status: event.status,
        source_lat: event.location.latitude,
        source_lng: event.location.longitude,
        receptors: event.receptors.map do |receptor|
          latest_calc = receptor.dispersion_calculations.order(created_at: :desc).first
          {
            id: receptor.id,
            name: receptor.name,
            lat: receptor.latitude,
            lng: receptor.longitude,
            concentration: latest_calc&.concentration || 0,
            health_impact: receptor.assess_health_impact(latest_calc&.concentration || 0)
          }
        end
      }
    end
  end
end
