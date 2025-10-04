class DispersionCalculationJob < ApplicationJob
  queue_as :default

  def perform(dispersion_event_id, receptor_id, weather_datum_id)
    @dispersion_event = DispersionEvent.find(dispersion_event_id)
    @receptor = Receptor.find(receptor_id)
    @weather_datum = WeatherDatum.find(weather_datum_id)
    
    # Create new calculation record
    calculation = @dispersion_event.dispersion_calculations.create!(
      weather_datum: @weather_datum,
      receptor_latitude: @receptor.latitude,
      receptor_longitude: @receptor.longitude,
      receptor_height: @receptor.height,
      calculation_type: 'gaussian_plume'
    )
    
    # Perform the actual physics calculation
    concentration = calculation.concentration_at_point(
      @receptor.latitude,
      @receptor.longitude,
      @receptor.height
    )
    
    # Update the calculation with results
    calculation.update!(
      concentration: concentration,
      effective_height: calculate_effective_height
    )
    
    # Broadcast results to WebSocket channels
    ActionCable.server.broadcast("dispersion_event_#{@dispersion_event.id}", {
      type: 'calculation_update',
      receptor_id: @receptor.id,
      concentration: concentration,
      health_impact: @receptor.assess_health_impact(concentration),
      timestamp: Time.current,
      weather: {
        wind_speed: @weather_datum.wind_speed,
        wind_direction: @weather_datum.wind_direction,
        stability_class: @weather_datum.stability_class
      }
    })

    # Also broadcast to general dispersion events channel
    ActionCable.server.broadcast("dispersion_events", {
      type: 'calculation_complete',
      event_id: @dispersion_event.id,
      calculation: {
        id: calculation.id,
        concentration: concentration,
        receptor_id: @receptor.id,
        timestamp: Time.current.iso8601
      }
    })
    
    Rails.logger.info "Dispersion calculation completed for receptor #{@receptor.name}: #{concentration} mg/m³"
    
  rescue StandardError => e
    Rails.logger.error "Dispersion calculation failed: #{e.message}"
    raise e
  end

  private

  def calculate_effective_height
    # Calculate effective release height accounting for plume rise
    # This is a simplified calculation - in practice would consider:
    # - Buoyancy effects from temperature difference
    # - Momentum effects from release velocity
    # - Atmospheric stability effects
    
    base_height = @dispersion_event.release_height
    temp_diff = @dispersion_event.release_temperature - @weather_datum.temperature
    
    # Simple buoyant plume rise formula (Briggs)
    if temp_diff > 0
      buoyancy_flux = 9.81 * @dispersion_event.release_rate * temp_diff / @dispersion_event.release_temperature
      plume_rise = 2.6 * (buoyancy_flux / (@weather_datum.wind_speed * @weather_datum.wind_speed * @weather_datum.wind_speed)) ** (1.0/3.0)
      base_height + plume_rise
    else
      base_height
    end
  end
end
