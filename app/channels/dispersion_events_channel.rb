# Dispersion Events Channel for real-time plume updates
# Broadcasts live calculation data and plume visualizations

class DispersionEventsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dispersion_events"
    
    # Send current active events data immediately
    transmit_active_events
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "Client unsubscribed from dispersion events channel"
  end

  # Client can subscribe to specific dispersion event updates
  def subscribe_to_event(data)
    event_id = data['event_id']
    
    if event_id.present?
      stream_from "dispersion_event_#{event_id}"
      
      # Send current data for this event
      event = DispersionEvent.find_by(id: event_id)
      if event
        transmit_event_data(event)
      end
    end
  end

  # Client can unsubscribe from specific event
  def unsubscribe_from_event(data)
    event_id = data['event_id']
    stop_stream_from "dispersion_event_#{event_id}" if event_id.present?
  end

  # Client can request immediate calculation update
  def request_calculation_update(data)
    event_id = data['event_id']
    
    if event_id.present?
      # Trigger background calculation job
      DispersionCalculationJob.perform_later(event_id)
      
      transmit({
        message: "Calculation update requested for event #{event_id}",
        status: 'queued',
        event_id: event_id
      })
    else
      transmit({
        error: "Event ID required for calculation update",
        status: 'error'
      })
    end
  end

  private

  def transmit_active_events
    active_events = DispersionEvent.where(status: 'active')
                                   .includes(:chemical, :location, :dispersion_calculations)
    
    events_data = active_events.map { |event| format_event_data(event) }
    
    transmit({
      type: 'active_events',
      events: events_data,
      timestamp: Time.current.iso8601
    })
  end

  def transmit_event_data(event)
    transmit({
      type: 'event_update',
      event: format_event_data(event),
      timestamp: Time.current.iso8601
    })
  end

  def format_event_data(event)
    latest_calc = event.dispersion_calculations.order(:created_at).last
    
    {
      id: event.id,
      chemical_name: event.chemical.name,
      location_name: event.location.name,
      status: event.status,
      source_coordinates: {
        lat: event.location.latitude,
        lng: event.location.longitude
      },
      release_rate: event.release_rate,
      latest_calculation: latest_calc ? {
        id: latest_calc.id,
        max_concentration: latest_calc.max_concentration,
        effective_height: latest_calc.effective_height,
        timestamp: latest_calc.created_at.iso8601
      } : nil,
      receptors: event.receptors.map do |receptor|
        {
          id: receptor.id,
          name: receptor.name,
          coordinates: {
            lat: receptor.latitude,
            lng: receptor.longitude
          },
          concentration: receptor.concentration || 0,
          health_impact: receptor.health_impact_level || 'unknown'
        }
      end
    }
  end
end