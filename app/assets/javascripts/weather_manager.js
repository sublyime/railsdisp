// Weather Map Integration
// Handles real-time weather data display and integration with dispersion calculations

class WeatherManager {
  constructor(map) {
    this.map = map;
    this.weatherStations = new Map();
    this.weatherLayer = null;
    this.currentWindLayer = null;
    this.weatherChannel = null;
    this.weatherUpdateInterval = null;
    
    this.initializeWeatherChannel();
    this.initializeWeatherLayer();
    this.setupWeatherControls();
  }

  // Initialize ActionCable connection for real-time weather updates
  initializeWeatherChannel() {
    // Use safe cable subscription creation
    if (typeof window.createCableSubscription === 'function') {
      window.createCableSubscription("WeatherChannel", {
        connected: () => {
          console.log('Connected to WeatherChannel');
          this.requestWeatherUpdate();
        },

        disconnected: () => {
          console.log('Disconnected from WeatherChannel');
        },

        received: (data) => {
          this.handleWeatherUpdate(data);
        },

        requestWeatherUpdate: (locationId = null) => {
          this.perform('request_weather_update', { location_id: locationId });
        },

        subscribeToLocation: (locationId) => {
          this.perform('subscribe_to_location', { location_id: locationId });
        }
      }).then(subscription => {
        this.weatherChannel = subscription;
      });
    } else {
      // Fallback to polling if ActionCable is not available
      console.log('ActionCable not available, using polling for weather updates');
      this.setupPollingFallback();
    }
  }

  // Fallback polling mechanism
  setupPollingFallback() {
    setInterval(() => {
      this.requestWeatherUpdate();
    }, 30000); // Poll every 30 seconds
  }

  // Create weather overlay layer on map
  initializeWeatherLayer() {
    if (!this.map) {
      console.error('Map not available for weather layer initialization');
      return;
    }

    this.weatherLayer = L.layerGroup();
    this.map.addLayer(this.weatherLayer);
    
    // Create wind vectors layer
    this.currentWindLayer = L.layerGroup();
    this.map.addLayer(this.currentWindLayer);
    
    // Add weather layer control if available
    if (window.layerControl) {
      window.layerControl.addOverlay(this.weatherLayer, "Weather Stations");
      window.layerControl.addOverlay(this.currentWindLayer, "Wind Vectors");
    }
  }

  // Setup weather control panel
  setupWeatherControls() {
    const weatherPanel = document.getElementById('weather-panel');
    if (!weatherPanel) return;

    // Create weather update button
    const updateButton = document.createElement('button');
    updateButton.className = 'btn btn-primary btn-sm mb-2';
    updateButton.innerHTML = '<i class="fas fa-sync"></i> Update Weather';
    updateButton.onclick = () => this.requestWeatherUpdate();
    weatherPanel.appendChild(updateButton);

    // Create wind vector toggle
    const windToggle = document.createElement('div');
    windToggle.className = 'form-check mb-2';
    windToggle.innerHTML = `
      <input class="form-check-input" type="checkbox" id="showWindVectors" checked>
      <label class="form-check-label" for="showWindVectors">
        Show Wind Vectors
      </label>
    `;
    weatherPanel.appendChild(windToggle);

    document.getElementById('showWindVectors').onchange = (e) => {
      if (e.target.checked) {
        this.map.addLayer(this.currentWindLayer);
      } else {
        this.map.removeLayer(this.currentWindLayer);
      }
    };

    // Create weather update interval control
    const intervalControl = document.createElement('div');
    intervalControl.className = 'mb-2';
    intervalControl.innerHTML = `
      <label class="form-label">Update Interval:</label>
      <select class="form-select form-select-sm" id="weatherInterval">
        <option value="30">30 seconds</option>
        <option value="60">1 minute</option>
        <option value="300">5 minutes</option>
        <option value="0">Manual only</option>
      </select>
    `;
    weatherPanel.appendChild(intervalControl);

    document.getElementById('weatherInterval').onchange = (e) => {
      this.setUpdateInterval(parseInt(e.target.value));
    };

    // Start with 30-second updates
    this.setUpdateInterval(30);
  }

  // Handle incoming weather data updates
  handleWeatherUpdate(data) {
    if (data.weather_data) {
      this.updateWeatherStation(data);
      this.updateWindVectors(data);
      
      // Update dispersion calculations if there are active events
      if (window.dispersionManager) {
        window.dispersionManager.updateWeatherData(data);
      }
    }
  }

  // Update weather station markers on map
  updateWeatherStation(data) {
    const { location_id, weather_data, coordinates } = data;
    const [lat, lon] = coordinates || [weather_data.latitude, weather_data.longitude];
    
    if (!lat || !lon) return;

    // Create or update weather station marker
    let stationMarker = this.weatherStations.get(location_id || `${lat}_${lon}`);
    
    if (!stationMarker) {
      stationMarker = L.marker([lat, lon], {
        icon: this.createWeatherIcon(weather_data)
      });
      
      this.weatherStations.set(location_id || `${lat}_${lon}`, stationMarker);
      this.weatherLayer.addLayer(stationMarker);
    } else {
      stationMarker.setIcon(this.createWeatherIcon(weather_data));
    }

    // Update popup content
    const popupContent = this.createWeatherPopup(weather_data);
    stationMarker.bindPopup(popupContent);
  }

  // Create weather station icon based on conditions
  createWeatherIcon(weatherData) {
    const temperature = weatherData.temperature;
    const windSpeed = weatherData.wind_speed;
    
    let iconClass = 'fas fa-thermometer-half';
    let iconColor = '#007bff';
    
    // Color based on temperature
    if (temperature < 0) {
      iconColor = '#0066cc';
      iconClass = 'fas fa-snowflake';
    } else if (temperature < 10) {
      iconColor = '#3399ff';
    } else if (temperature < 25) {
      iconColor = '#66cc66';
    } else if (temperature < 35) {
      iconColor = '#ffcc00';
    } else {
      iconColor = '#ff6600';
    }

    // Add wind indicator for high winds
    if (windSpeed > 10) {
      iconClass = 'fas fa-wind';
    }

    return L.divIcon({
      html: `<i class="${iconClass}" style="color: ${iconColor}; font-size: 16px;"></i>`,
      className: 'weather-station-icon',
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });
  }

  // Create detailed weather popup
  createWeatherPopup(weatherData) {
    const recordedTime = new Date(weatherData.recorded_at);
    const ageMinutes = weatherData.age_minutes || 0;
    
    return `
      <div class="weather-popup">
        <h6><i class="fas fa-cloud-sun"></i> Weather Conditions</h6>
        <table class="table table-sm">
          <tr><td>Temperature:</td><td>${weatherData.temperature}°C</td></tr>
          <tr><td>Wind Speed:</td><td>${weatherData.wind_speed} m/s</td></tr>
          <tr><td>Wind Direction:</td><td>${weatherData.wind_direction}°</td></tr>
          <tr><td>Humidity:</td><td>${weatherData.humidity}%</td></tr>
          <tr><td>Pressure:</td><td>${weatherData.pressure} hPa</td></tr>
          <tr><td>Stability Class:</td><td><span class="badge bg-info">${weatherData.stability_class || 'D'}</span></td></tr>
          <tr><td>Data Age:</td><td>${ageMinutes} minutes</td></tr>
        </table>
        <div class="text-muted">
          <small>Recorded: ${recordedTime.toLocaleString()}</small><br>
          <small>Source: ${weatherData.source}</small>
        </div>
      </div>
    `;
  }

  // Update wind vector display
  updateWindVectors(data) {
    const { weather_data, coordinates } = data;
    const [lat, lon] = coordinates || [weather_data.latitude, weather_data.longitude];
    
    if (!lat || !lon || !weather_data.wind_speed) return;

    // Remove existing wind vector at this location
    this.currentWindLayer.eachLayer(layer => {
      if (layer.options.locationKey === `${lat}_${lon}`) {
        this.currentWindLayer.removeLayer(layer);
      }
    });

    // Create wind vector arrow
    const windVector = this.createWindVector(lat, lon, weather_data);
    if (windVector) {
      windVector.options.locationKey = `${lat}_${lon}`;
      this.currentWindLayer.addLayer(windVector);
    }
  }

  // Create wind direction arrow
  createWindVector(lat, lon, weatherData) {
    const windSpeed = weatherData.wind_speed;
    const windDirection = weatherData.wind_direction;
    
    if (windSpeed < 0.5) return null; // Don't show vectors for very light winds

    // Calculate arrow endpoint based on wind direction and speed
    const arrowLength = Math.min(windSpeed * 0.002, 0.05); // Scale based on wind speed
    const directionRad = (windDirection + 180) * Math.PI / 180; // Wind direction is "coming from"
    
    const endLat = lat + arrowLength * Math.cos(directionRad);
    const endLon = lon + arrowLength * Math.sin(directionRad);

    // Color based on wind speed
    let color = '#1f77b4';
    if (windSpeed > 15) color = '#d62728';
    else if (windSpeed > 10) color = '#ff7f0e';
    else if (windSpeed > 5) color = '#2ca02c';

    const polyline = L.polyline([[lat, lon], [endLat, endLon]], {
      color: color,
      weight: 3,
      opacity: 0.8
    });

    // Add arrowhead
    const arrowHead = L.polygon([
      [endLat, endLon],
      [endLat - arrowLength * 0.3 * Math.cos(directionRad - 0.5), 
       endLon - arrowLength * 0.3 * Math.sin(directionRad - 0.5)],
      [endLat - arrowLength * 0.3 * Math.cos(directionRad + 0.5), 
       endLon - arrowLength * 0.3 * Math.sin(directionRad + 0.5)]
    ], {
      color: color,
      fillColor: color,
      fillOpacity: 0.8,
      weight: 2
    });

    // Create layer group for arrow
    const arrowGroup = L.layerGroup([polyline, arrowHead]);
    
    // Add popup with wind details
    arrowGroup.bindPopup(`
      <div class="wind-popup">
        <h6><i class="fas fa-wind"></i> Wind Vector</h6>
        <p><strong>Speed:</strong> ${windSpeed.toFixed(1)} m/s</p>
        <p><strong>Direction:</strong> ${windDirection}° (${this.getWindDirectionText(windDirection)})</p>
        <p><strong>Stability:</strong> ${weatherData.stability_class || 'D'}</p>
      </div>
    `);

    return arrowGroup;
  }

  // Convert wind direction to compass text
  getWindDirectionText(degrees) {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 
                       'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    const index = Math.round(degrees / 22.5) % 16;
    return directions[index];
  }

  // Request weather update from server
  requestWeatherUpdate(locationId = null) {
    if (this.weatherChannel) {
      this.weatherChannel.requestWeatherUpdate(locationId);
    } else {
      // Fallback to AJAX request
      const url = locationId 
        ? `/weather/update_location?location_id=${locationId}`
        : '/weather/update_all';
      
      fetch(url, { method: 'POST' })
        .then(response => response.json())
        .then(data => console.log('Weather update requested:', data))
        .catch(error => console.error('Weather update failed:', error));
    }
  }

  // Set automatic weather update interval
  setUpdateInterval(seconds) {
    if (this.weatherUpdateInterval) {
      clearInterval(this.weatherUpdateInterval);
    }

    if (seconds > 0) {
      this.weatherUpdateInterval = setInterval(() => {
        this.requestWeatherUpdate();
      }, seconds * 1000);
      
      console.log(`Weather updates set to every ${seconds} seconds`);
    } else {
      console.log('Automatic weather updates disabled');
    }
  }

  // Get current weather for specific coordinates
  async getCurrentWeather(lat, lon) {
    try {
      const response = await fetch(`/api/v1/weather_data/current/${lat}/${lon}`);
      const data = await response.json();
      
      if (data.success) {
        return data.data.weather_data;
      } else {
        throw new Error(data.message || 'Failed to fetch weather data');
      }
    } catch (error) {
      console.error('Error fetching current weather:', error);
      throw error;
    }
  }

  // Get weather forecast for specific coordinates
  async getForecast(lat, lon, hours = 24) {
    try {
      const response = await fetch(`/api/v1/weather_data/forecast/${lat}/${lon}?hours=${hours}`);
      const data = await response.json();
      
      if (data.success) {
        return data.data.forecast_data;
      } else {
        throw new Error(data.message || 'Failed to fetch forecast data');
      }
    } catch (error) {
      console.error('Error fetching forecast:', error);
      throw error;
    }
  }

  // Clean up resources
  destroy() {
    if (this.weatherUpdateInterval) {
      clearInterval(this.weatherUpdateInterval);
    }
    
    if (this.weatherChannel) {
      this.weatherChannel.unsubscribe();
    }
    
    if (this.weatherLayer) {
      this.map.removeLayer(this.weatherLayer);
    }
    
    if (this.currentWindLayer) {
      this.map.removeLayer(this.currentWindLayer);
    }
  }
}

// Initialize weather manager when map is ready
document.addEventListener('DOMContentLoaded', function() {
  // Listen for map ready event
  document.addEventListener('mapReady', function(event) {
    if (event.detail && event.detail.map) {
      window.weatherManager = new WeatherManager(event.detail.map);
      console.log('WeatherManager initialized via mapReady event');
    }
  });
  
  // Function to initialize WeatherManager with proper map validation
  const initializeWeatherManager = () => {
    // Check multiple possible map references
    const map = window.dispersionMap || window.map || (window.L && window.L.map);
    
    if (map && typeof map.addLayer === 'function') {
      window.weatherManager = new WeatherManager(map);
      console.log('WeatherManager initialized with map');
      return true;
    }
    return false;
  };
  
  // Try immediate initialization
  if (!initializeWeatherManager()) {
    // Wait for map initialization with more comprehensive checks
    let attempts = 0;
    const maxAttempts = 100; // 10 second timeout
    
    const checkMapInterval = setInterval(() => {
      attempts++;
      
      if (initializeWeatherManager() || attempts >= maxAttempts) {
        clearInterval(checkMapInterval);
        if (attempts >= maxAttempts) {
          console.warn('WeatherManager: Map initialization timeout after', attempts * 100, 'ms');
          // Initialize with a placeholder that can be updated later
          window.weatherManager = {
            map: null,
            initialized: false,
            initializeWithMap: function(map) {
              if (map && typeof map.addLayer === 'function') {
                window.weatherManager = new WeatherManager(map);
                console.log('WeatherManager initialized with delayed map');
              }
            }
          };
        }
      }
    }, 100);
  }
});

// Make WeatherManager globally available
if (typeof window !== 'undefined') {
  window.WeatherManager = WeatherManager;
}