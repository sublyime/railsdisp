class ContinuousDispersionJob < ApplicationJob
  queue_as :default

  def perform(dispersion_event_id)
    @dispersion_event = DispersionEvent.find(dispersion_event_id)
    
    Rails.logger.info "Starting continuous monitoring for event #{@dispersion_event.id}"
    
    # Continue monitoring while event is active
    while @dispersion_event.reload.status == 'active'
      # Get latest weather data
      current_weather = WeatherDatum.order(timestamp: :desc).first
      
      if current_weather && weather_updated?(current_weather)
        # Run calculations for all receptors with new weather data
        @dispersion_event.receptors.find_each do |receptor|
          DispersionCalculationJob.perform_later(
            @dispersion_event.id,
            receptor.id,
            current_weather.id
          )
        end
        
        # Generate and broadcast plume contours
        broadcast_plume_update(current_weather)
        
        # Update last calculation timestamp
        @dispersion_event.touch(:updated_at)
      end
      
      # Wait 30 seconds before next calculation cycle
      sleep(30)
    end
    
    Rails.logger.info "Continuous monitoring stopped for event #{@dispersion_event.id}"
    
  rescue StandardError => e
    Rails.logger.error "Continuous dispersion monitoring failed: #{e.message}"
    @dispersion_event.update(status: 'error') if @dispersion_event
    raise e
  end

  private

  def weather_updated?(current_weather)
    # Check if weather data is newer than last calculation
    last_calculation = @dispersion_event.dispersion_calculations.order(created_at: :desc).first
    return true unless last_calculation
    
    current_weather.timestamp > last_calculation.created_at
  end

  def broadcast_plume_update(weather_data)
    # Create a temporary calculation to generate plume contours
    temp_calculation = @dispersion_event.dispersion_calculations.build(
      weather_datum: weather_data,
      receptor_latitude: @dispersion_event.location.latitude,
      receptor_longitude: @dispersion_event.location.longitude,
      receptor_height: 1.5,
      calculation_type: 'plume_visualization'
    )
    
    # Generate plume contour data
    plume_contours = temp_calculation.generate_plume_contours
    
    # Broadcast to all subscribers
    ActionCable.server.broadcast("dispersion_event_#{@dispersion_event.id}", {
      type: 'plume_update',
      source_location: {
        lat: @dispersion_event.location.latitude,
        lng: @dispersion_event.location.longitude
      },
      contours: plume_contours,
      weather: {
        wind_speed: weather_data.wind_speed,
        wind_direction: weather_data.wind_direction,
        temperature: weather_data.temperature,
        stability_class: weather_data.stability_class,
        timestamp: weather_data.timestamp
      },
      event_status: @dispersion_event.status,
      timestamp: Time.current
    })
    
    # Also broadcast to general monitoring channel
    ActionCable.server.broadcast('dispersion_monitoring', {
      type: 'event_update',
      event_id: @dispersion_event.id,
      chemical_name: @dispersion_event.chemical.name,
      location_name: @dispersion_event.location.name,
      active_receptors: @dispersion_event.receptors.count,
      latest_max_concentration: calculate_max_concentration,
      timestamp: Time.current
    })
  end

  def calculate_max_concentration
    # Find the highest concentration from recent calculations
    recent_calculations = @dispersion_event.dispersion_calculations
                                          .where('created_at > ?', 5.minutes.ago)
    
    return 0 if recent_calculations.empty?
    
    recent_calculations.maximum(:concentration) || 0
  end
end
