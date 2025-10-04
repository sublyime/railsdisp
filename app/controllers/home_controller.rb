class HomeController < ApplicationController
  include WeatherHelper
  
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

  def simple_dashboard
    # Simple map dashboard without complex JavaScript
    @active_events = DispersionEvent.where(status: 'active')
                                   .includes(:chemical, :location)
    
    @locations = Location.all
    @chemicals = Chemical.all
    @weather_data = WeatherDatum.all
    
    render layout: 'simple_map'
  end

  def dashboard
    # Main operational dashboard
    @active_events = DispersionEvent.where(status: 'active')
                                   .includes(:chemical, :location, :receptors, :dispersion_calculations)
    
    @recent_calculations = DispersionCalculation.includes(:dispersion_event, :weather_datum)
                                               .order(created_at: :desc)
                                               .limit(10)
    
    @current_weather = WeatherDatum.order(recorded_at: :desc).first
    
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
          # Get the latest calculation for this event and find concentration at this receptor
          latest_calc = event.dispersion_calculations.order(created_at: :desc).first
          
          if latest_calc
            # Calculate concentration at this receptor location
            concentration = latest_calc.concentration_at_point(receptor.latitude, receptor.longitude)
          else
            concentration = receptor.concentration || 0
          end
          
          # Determine health impact based on concentration
          health_impact = case concentration
          when 0...0.1 then 'safe'
          when 0.1...1.0 then 'caution'
          when 1.0...10.0 then 'warning'
          else 'danger'
          end
          
          {
            id: receptor.id,
            name: receptor.name,
            lat: receptor.latitude,
            lng: receptor.longitude,
            concentration: concentration,
            health_impact: health_impact
          }
        end
      }
    end
  end
end
