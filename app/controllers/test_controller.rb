# Test controller for WebSocket functionality
class TestController < ApplicationController
  def trigger_weather_broadcast
    # Broadcast fake weather data to test WebSocket connection
    ActionCable.server.broadcast(
      "weather_channel",
      {
        location_id: 1,
        weather_data: {
          temperature: 22.5,
          humidity: 65,
          wind_speed: 3.2,
          wind_direction: 180,
          timestamp: Time.current
        },
        stability_class: 'D'
      }
    )
    
    render json: { status: 'success', message: 'Weather broadcast sent' }
  end

  def trigger_dispersion_broadcast
    # Broadcast fake dispersion data to test WebSocket connection
    ActionCable.server.broadcast(
      "dispersion_events_channel",
      {
        event_id: 3,
        plume_data: {
          concentrations: [
            { lat: 32.776664, lng: -96.796988, value: 0.5 },
            { lat: 32.777664, lng: -96.797988, value: 0.3 },
            { lat: 32.778664, lng: -96.798988, value: 0.1 }
          ],
          wind_direction: 180,
          timestamp: Time.current
        }
      }
    )
    
    render json: { status: 'success', message: 'Dispersion broadcast sent' }
  end

  def websocket_test
    render plain: "WebSocket test endpoints:\n/test/weather_broadcast\n/test/dispersion_broadcast"
  end
end