// Simple Dashboard Map Implementation
// Only loads on dashboard page, no complex initialization logic

class SimpleDashboardMap {
  constructor() {
    this.map = null;
    this.markers = {};
    this.init();
  }

  init() {
    // Only initialize if we're on the dashboard page
    const mapContainer = document.getElementById('dispersionMap');
    if (!mapContainer) {
      console.log('📍 Not on dashboard page, skipping map initialization');
      return;
    }

    console.log('🗺️ Initializing simple dashboard map...');
    this.createMap();
    this.loadInitialData();
  }

  createMap() {
    try {
      // Create the Leaflet map
      this.map = L.map('dispersionMap').setView([39.8283, -98.5795], 6); // Center of USA

      // Add OpenStreetMap tiles
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 18
      }).addTo(this.map);

      // Add click handler for weather data
      this.map.on('click', (e) => this.handleMapClick(e));

      console.log('✅ Simple map created successfully');
    } catch (error) {
      console.error('❌ Error creating map:', error);
    }
  }

  async handleMapClick(e) {
    const { lat, lng } = e.latlng;
    console.log(`🌤️ Getting weather for coordinates: ${lat}, ${lng}`);

    try {
      // Add a temporary marker
      const tempMarker = L.marker([lat, lng])
        .addTo(this.map)
        .bindPopup('Loading weather data...')
        .openPopup();

      // Fetch weather data
      const response = await fetch(`/api/v1/weather/at_location?lat=${lat}&lng=${lng}`);
      const data = await response.json();

      if (response.ok && data.success) {
        // Update popup with weather data
        const weatherData = data.data;
        const popupContent = `
          <div class="weather-popup">
            <h6><strong>Weather Data</strong></h6>
            <p><strong>Location:</strong> ${lat.toFixed(4)}, ${lng.toFixed(4)}</p>
            <p><strong>Temperature:</strong> ${weatherData.temperature}°C</p>
            <p><strong>Wind Speed:</strong> ${weatherData.wind_speed} m/s</p>
            <p><strong>Wind Direction:</strong> ${weatherData.wind_direction}°</p>
            <p><strong>Humidity:</strong> ${weatherData.humidity}%</p>
            <p><strong>Pressure:</strong> ${weatherData.pressure} hPa</p>
            <small class="text-muted">Click elsewhere for more weather data</small>
          </div>
        `;
        
        tempMarker.setPopupContent(popupContent);
        console.log('✅ Weather data loaded successfully');
      } else {
        tempMarker.setPopupContent(`
          <div class="error-popup">
            <h6><strong>Weather Data</strong></h6>
            <p>Error loading weather data</p>
            <small>${data.message || 'Unknown error'}</small>
          </div>
        `);
      }
    } catch (error) {
      console.error('❌ Error fetching weather data:', error);
      e.target.setPopupContent(`
        <div class="error-popup">
          <h6><strong>Weather Data</strong></h6>
          <p>Error loading weather data</p>
          <small>${error.message}</small>
        </div>
      `);
    }
  }

  async loadInitialData() {
    try {
      // Load dispersion events
      const eventsResponse = await fetch('/api/v1/dispersion_events');
      if (eventsResponse.ok) {
        const eventData = await eventsResponse.json();
        if (eventData.success && eventData.data) {
          this.addDispersionEvents(eventData.data);
        }
      }

      // Load locations
      const locationsResponse = await fetch('/api/v1/locations');
      if (locationsResponse.ok) {
        const locationData = await locationsResponse.json();
        if (locationData.success && locationData.data && locationData.data.locations) {
          this.addLocations(locationData.data.locations);
        }
      }

      console.log('✅ Initial data loaded');
    } catch (error) {
      console.error('❌ Error loading initial data:', error);
    }
  }

  addDispersionEvents(events) {
    events.forEach(event => {
      if (event.source_coordinates && event.source_coordinates.lat && event.source_coordinates.lng) {
        const marker = L.marker([event.source_coordinates.lat, event.source_coordinates.lng], {
          icon: L.divIcon({
            className: 'dispersion-event-marker',
            html: `
              <div style="background: #dc3545; color: white; border-radius: 50%; width: 30px; height: 30px; 
                          display: flex; align-items: center; justify-content: center; font-size: 12px; 
                          border: 2px solid white; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
                <i class="fas fa-exclamation"></i>
              </div>
            `,
            iconSize: [30, 30],
            iconAnchor: [15, 15]
          })
        }).addTo(this.map);

        marker.bindPopup(`
          <div class="event-popup">
            <h6><strong>Dispersion Event #${event.id}</strong></h6>
            <p><strong>Chemical:</strong> ${event.chemical || 'Unknown'}</p>
            <p><strong>Location:</strong> ${event.location || 'Unknown'}</p>
            <p><strong>Status:</strong> ${event.status || 'Active'}</p>
            <div class="mt-2">
              <a href="/dispersion_events/${event.id}" class="btn btn-sm btn-primary">View Details</a>
            </div>
          </div>
        `);

        this.markers[`event_${event.id}`] = marker;
      }
    });
  }

  addLocations(locations) {
    locations.forEach(location => {
      const marker = L.marker([location.latitude, location.longitude], {
        icon: L.divIcon({
          className: 'location-marker',
          html: `
            <div style="background: #28a745; color: white; border-radius: 3px; width: 25px; height: 25px; 
                        display: flex; align-items: center; justify-content: center; font-size: 10px; 
                        border: 2px solid white; box-shadow: 0 1px 3px rgba(0,0,0,0.3);">
              <i class="fas fa-building"></i>
            </div>
          `,
          iconSize: [25, 25],
          iconAnchor: [12, 12]
        })
      }).addTo(this.map);

      marker.bindPopup(`
        <div class="location-popup">
          <h6><strong>${location.name}</strong></h6>
          <p><strong>Type:</strong> ${location.terrain_type || 'Unknown'}</p>
          <p><strong>Coordinates:</strong> ${location.latitude}, ${location.longitude}</p>
          <div class="mt-2">
            <a href="/locations/${location.id}" class="btn btn-sm btn-info">View Details</a>
            <button class="btn btn-sm btn-success" onclick="window.location.href='/dispersion_events/new?location_id=${location.id}'">
              New Event Here
            </button>
          </div>
        </div>
      `);

      this.markers[`location_${location.id}`] = marker;
    });
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Only initialize if we're on dashboard page
  if (document.getElementById('dispersionMap')) {
    console.log('🚀 Initializing Simple Dashboard Map...');
    window.simpleDashboardMap = new SimpleDashboardMap();
  }
});

// Also initialize on Turbo navigation
document.addEventListener('turbo:load', function() {
  // Only initialize if we're on dashboard page and map doesn't exist
  if (document.getElementById('dispersionMap') && !window.simpleDashboardMap) {
    console.log('🚀 Initializing Simple Dashboard Map after Turbo navigation...');
    window.simpleDashboardMap = new SimpleDashboardMap();
  }
});