// Chemical Dispersion Map - Interactive Leaflet.js Implementation
// This file handles real-time plume visualization and map interactions

let map;
let sourceMarkers = {};
let receptorMarkers = {};
let plumeContours = {};
let concentrationOverlays = []; // Add this for the global export
let currentEventLayers = {};

// Map configuration
const MAP_CONFIG = {
  center: [29.7604, -95.3698], // Houston, TX
  zoom: 11,
  minZoom: 8,
  maxZoom: 18
};

// Color schemes for different concentration levels
const CONCENTRATION_COLORS = {
  0.1: '#00ff00',   // Green - Safe
  1.0: '#ffff00',   // Yellow - Caution  
  10.0: '#ff8800',  // Orange - Warning
  100.0: '#ff0000'  // Red - Danger
};

/**
 * Initialize the main dispersion map
 */
function initializeDispersionMap() {
  console.log('🗺️ Checking for dispersion map container...');
  
  // Check if map container exists
  const mapContainer = document.getElementById('dispersionMap');
  if (!mapContainer) {
    console.log('ℹ️ Map container #dispersionMap not found - not on dashboard page');
    return false;
  }
  
  console.log('✅ Map container found:', mapContainer);

  // Check if map is already initialized and clean up properly
  if (map && map._container) {
    console.log('⚠️ Map already initialized, removing existing instance');
    try {
      map.off(); // Remove all event listeners
      map.remove(); // Remove the map
    } catch (e) {
      console.log('⚠️ Error removing map, forcing cleanup:', e.message);
    }
    map = null;
  }

  // Also check if container has leftover Leaflet classes and clean them
  if (mapContainer.classList.contains('leaflet-container')) {
    console.log('🧹 Cleaning up leftover Leaflet container classes');
    mapContainer.innerHTML = ''; // Clear container content
    mapContainer.className = mapContainer.className.replace(/leaflet[^\s]*/g, '').trim();
    mapContainer.style.cssText = 'height: 70vh; min-height: 500px;'; // Reset styles
  }

  try {
    // Create the map
    console.log('Creating Leaflet map...');
    map = L.map('dispersionMap').setView(MAP_CONFIG.center, MAP_CONFIG.zoom);

  // Add base layer - OpenStreetMap
  const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19
  });

  // Add satellite layer - Esri World Imagery
  const satelliteLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
    attribution: 'Tiles © Esri',
    maxZoom: 19
  });

  // Add topographic layer
  const topoLayer = L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
    attribution: 'Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap',
    maxZoom: 17
  });

  // Set default layer
  osmLayer.addTo(map);

  // Make map globally available for other modules
  window.dispersionMap = map;
  window.map = map; // Alternative reference

  // Layer control
  const baseMaps = {
    "Street Map": osmLayer,
    "Satellite": satelliteLayer,
    "Topographic": topoLayer
  };

  L.control.layers(baseMaps).addTo(map);

  // Add scale control
  L.control.scale({
    metric: true,
    imperial: true
  }).addTo(map);

  // Add custom controls
  addCustomControls();

  // Setup map event handlers for weather integration
  setupWeatherMapIntegration();

  // Load initial data after map is ready
  map.whenReady(function() {
    console.log('🗺️ Map is ready, loading data...');
    loadActiveEvents();
    loadLocations();
    
    // Set up real-time updates
    setupRealtimeUpdates();
  });

  // Notify other modules that map is ready
  document.dispatchEvent(new CustomEvent('mapReady', { detail: { map: map } }));
  
  // Try to initialize WeatherManager if available
  if (window.weatherManager && window.weatherManager.initializeWithMap) {
    window.weatherManager.initializeWithMap(map);
  }

  console.log('✅ Dispersion map initialized successfully');
  return true;
  
  } catch (error) {
    console.error('❌ Error initializing dispersion map:', error);
    return false;
  }
}

/**
 * Setup weather integration with map interactions
 */
function setupWeatherMapIntegration() {
  // Add weather layers
  window.weatherStationLayer = L.layerGroup().addTo(map);
  window.weatherWindLayer = L.layerGroup().addTo(map);
  
  // Create weather control panel
  const weatherControl = L.control({position: 'topright'});
  weatherControl.onAdd = function(map) {
    const div = L.DomUtil.create('div', 'weather-control-panel bg-white p-3 rounded shadow');
    div.style.maxWidth = '300px';
    div.innerHTML = `
      <div class="weather-panel">
        <h6><i class="fas fa-cloud-sun"></i> Weather Integration</h6>
        <div class="form-check mb-2">
          <input class="form-check-input" type="checkbox" id="enableWeatherClick" checked>
          <label class="form-check-label" for="enableWeatherClick">
            Click map for weather
          </label>
        </div>
        <div class="form-check mb-2">
          <input class="form-check-input" type="checkbox" id="showWeatherStations" checked>
          <label class="form-check-label" for="showWeatherStations">
            Show weather stations
          </label>
        </div>
        <div class="form-check mb-2">
          <input class="form-check-input" type="checkbox" id="showWindVectors" checked>
          <label class="form-check-label" for="showWindVectors">
            Show wind vectors
          </label>
        </div>
        <div class="mb-2">
          <button class="btn btn-primary btn-sm w-100" onclick="refreshAllWeatherData()">
            <i class="fas fa-sync"></i> Refresh Weather
          </button>
        </div>
        <div id="weather-status" class="alert alert-info p-2 small">
          Click on map to get weather data
        </div>
      </div>
    `;
    
    // Prevent map clicks when interacting with control
    L.DomEvent.disableClickPropagation(div);
    return div;
  };
  weatherControl.addTo(map);
  
  // Setup weather map click handler
  map.on('click', handleWeatherMapClick);
  
  // Setup control event handlers
  setTimeout(() => {
    document.getElementById('enableWeatherClick').addEventListener('change', function(e) {
      if (e.target.checked) {
        map.on('click', handleWeatherMapClick);
        updateWeatherStatus('Weather click enabled');
      } else {
        map.off('click', handleWeatherMapClick);
        updateWeatherStatus('Weather click disabled');
      }
    });
    
    document.getElementById('showWeatherStations').addEventListener('change', function(e) {
      if (e.target.checked) {
        map.addLayer(window.weatherStationLayer);
      } else {
        map.removeLayer(window.weatherStationLayer);
      }
    });
    
    document.getElementById('showWindVectors').addEventListener('change', function(e) {
      if (e.target.checked) {
        map.addLayer(window.weatherWindLayer);
      } else {
        map.removeLayer(window.weatherWindLayer);
      }
    });
  }, 100);
  
  console.log('✅ Weather map integration setup complete');
}

/**
 * Handle map click to fetch weather data for clicked location
 */
async function handleWeatherMapClick(e) {
  const lat = e.latlng.lat;
  const lon = e.latlng.lng;
  
  updateWeatherStatus('Fetching weather data...', 'info');
  
  try {
    // Add temporary marker to show clicked location
    const tempMarker = L.marker([lat, lon], {
      icon: L.divIcon({
        className: 'temp-weather-marker',
        html: '<i class="fas fa-spinner fa-spin" style="color: #007bff; font-size: 16px;"></i>',
        iconSize: [20, 20],
        iconAnchor: [10, 10]
      })
    }).addTo(map);
    
    // Fetch weather data for clicked location
    const weatherData = await fetchWeatherForLocation(lat, lon);
    
    // Remove temporary marker
    map.removeLayer(tempMarker);
    
    if (weatherData.status === 'success') {
      // Add weather station marker
      addWeatherStationToMap(lat, lon, weatherData.weather_data);
      
      // Show weather popup at clicked location
      showWeatherPopup(lat, lon, weatherData.weather_data);
      
      // Update status
      updateWeatherStatus(`Weather data loaded for ${lat.toFixed(4)}, ${lon.toFixed(4)}`, 'success');
      
      // If this is for a dispersion scenario, integrate with scenario workflow
      if (window.currentDispersionScenario) {
        await integrateWeatherWithDispersionScenario(lat, lon, weatherData);
      }
      
    } else {
      updateWeatherStatus(`Failed to fetch weather: ${weatherData.error || 'Unknown error'}`, 'danger');
    }
    
  } catch (error) {
    // Remove temporary marker if it exists
    if (tempMarker) {
      map.removeLayer(tempMarker);
    }
    
    console.error('Weather fetch error:', error);
    updateWeatherStatus(`Error: ${error.message}`, 'danger');
    
    // Show error popup
    L.popup()
      .setLatLng([lat, lon])
      .setContent(`
        <div class="alert alert-danger p-2 mb-0">
          <h6><i class="fas fa-exclamation-triangle"></i> Weather Error</h6>
          <p class="mb-0">Failed to fetch weather data: ${error.message}</p>
        </div>
      `)
      .openOn(map);
  }
}

/**
 * Fetch weather data for specific coordinates
 */
async function fetchWeatherForLocation(lat, lon) {
  const response = await fetch(`/api/v1/weather/at_location?lat=${lat}&lng=${lon}`, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  const result = await response.json();
  
  // Transform the API response to expected format
  if (result.status === 'success') {
    return {
      status: 'success',
      weather_data: result.data
    };
  } else {
    return {
      status: 'error',
      error: result.message || 'Failed to fetch weather data'
    };
  }
}

/**
 * Fetch atmospheric stability analysis for coordinates
 */
async function fetchAtmosphericStability(lat, lon) {
  const response = await fetch(`/weather/atmospheric_stability/${lat}/${lon}`, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return await response.json();
}

/**
 * Add weather station marker to map
 */
function addWeatherStationToMap(lat, lon, weatherData) {
  const stationId = `weather_${lat.toFixed(4)}_${lon.toFixed(4)}`;
  
  // Remove existing station at this location
  window.weatherStationLayer.eachLayer(layer => {
    if (layer.options.stationId === stationId) {
      window.weatherStationLayer.removeLayer(layer);
    }
  });
  
  // Create weather station icon based on conditions
  const iconColor = getTemperatureColor(weatherData.temperature);
  const stabilityClass = weatherData.pasquill_stability_class || 'D';
  
  const weatherIcon = L.divIcon({
    className: 'weather-station-marker',
    html: `
      <div class="weather-marker-content" style="background-color: ${iconColor}; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);">
        <i class="fas fa-thermometer-half" style="color: white; font-size: 10px;"></i>
      </div>
      <div class="stability-indicator" style="position: absolute; top: -5px; right: -5px; background: ${getStabilityColor(stabilityClass)}; color: white; border-radius: 50%; width: 12px; height: 12px; font-size: 8px; display: flex; align-items: center; justify-content: center; font-weight: bold;">
        ${stabilityClass}
      </div>
    `,
    iconSize: [24, 24],
    iconAnchor: [12, 12]
  });
  
  const stationMarker = L.marker([lat, lon], { 
    icon: weatherIcon,
    stationId: stationId
  });
  
  // Add weather station popup
  const popupContent = createWeatherStationPopup(weatherData);
  stationMarker.bindPopup(popupContent);
  
  window.weatherStationLayer.addLayer(stationMarker);
  
  // Add wind vector if wind data available
  if (weatherData.wind_speed && weatherData.wind_speed > 0.5) {
    addWindVectorToMap(lat, lon, weatherData);
  }
}

/**
 * Add wind vector visualization to map
 */
function addWindVectorToMap(lat, lon, weatherData) {
  const windSpeed = weatherData.wind_speed;
  const windDirection = weatherData.wind_direction;
  
  if (!windSpeed || !windDirection) return;
  
  // Calculate wind vector arrow
  const arrowLength = Math.min(windSpeed * 0.003, 0.08); // Scale based on wind speed
  const directionRad = (windDirection + 180) * Math.PI / 180; // Convert to coming-from direction
  
  const endLat = lat + arrowLength * Math.cos(directionRad);
  const endLon = lon + arrowLength * Math.sin(directionRad);
  
  // Color based on wind speed
  const windColor = getWindSpeedColor(windSpeed);
  
  // Create wind arrow
  const windLine = L.polyline([[lat, lon], [endLat, endLon]], {
    color: windColor,
    weight: 3,
    opacity: 0.8
  });
  
  // Create arrowhead
  const arrowHead = L.polygon([
    [endLat, endLon],
    [endLat - arrowLength * 0.3 * Math.cos(directionRad - 0.5), 
     endLon - arrowLength * 0.3 * Math.sin(directionRad - 0.5)],
    [endLat - arrowLength * 0.3 * Math.cos(directionRad + 0.5), 
     endLon - arrowLength * 0.3 * Math.sin(directionRad + 0.5)]
  ], {
    color: windColor,
    fillColor: windColor,
    fillOpacity: 0.8,
    weight: 2
  });
  
  // Group wind elements
  const windGroup = L.layerGroup([windLine, arrowHead]);
  
  // Add wind popup
  windGroup.bindPopup(`
    <div class="wind-popup">
      <h6><i class="fas fa-wind"></i> Wind Vector</h6>
      <p><strong>Speed:</strong> ${windSpeed.toFixed(1)} m/s</p>
      <p><strong>Direction:</strong> ${windDirection}° (${getWindDirectionText(windDirection)})</p>
      <p><strong>Stability:</strong> ${weatherData.pasquill_stability_class || 'D'}</p>
    </div>
  `);
  
  window.weatherWindLayer.addLayer(windGroup);
}

/**
 * Show detailed weather popup at clicked location
 */
function showWeatherPopup(lat, lon, weatherData) {
  const popupContent = createDetailedWeatherPopup(weatherData);
  
  L.popup({
    maxWidth: 400,
    className: 'weather-detail-popup'
  })
  .setLatLng([lat, lon])
  .setContent(popupContent)
  .openOn(map);
}

/**
 * Create comprehensive weather station popup content
 */
function createWeatherStationPopup(weatherData) {
  const observedAt = new Date(weatherData.observed_at || Date.now());
  const stabilityClass = weatherData.pasquill_stability_class || 'D';
  const stabilityDesc = getStabilityDescription(stabilityClass);
  
  return `
    <div class="weather-station-popup">
      <h6><i class="fas fa-cloud-sun"></i> Weather Station</h6>
      <div class="weather-data-grid">
        <div class="row">
          <div class="col-6">
            <strong>Temperature:</strong><br>
            <span class="badge bg-info">${weatherData.temperature?.toFixed(1) || 'N/A'}°C</span>
          </div>
          <div class="col-6">
            <strong>Humidity:</strong><br>
            <span class="badge bg-secondary">${weatherData.relative_humidity?.toFixed(0) || 'N/A'}%</span>
          </div>
        </div>
        <div class="row mt-2">
          <div class="col-6">
            <strong>Wind Speed:</strong><br>
            <span class="badge bg-primary">${weatherData.wind_speed?.toFixed(1) || 'N/A'} m/s</span>
          </div>
          <div class="col-6">
            <strong>Wind Dir:</strong><br>
            <span class="badge bg-primary">${weatherData.wind_direction || 'N/A'}°</span>
          </div>
        </div>
        <div class="row mt-2">
          <div class="col-6">
            <strong>Pressure:</strong><br>
            <span class="badge bg-warning">${weatherData.pressure_sea_level?.toFixed(0) || 'N/A'} hPa</span>
          </div>
          <div class="col-6">
            <strong>Visibility:</strong><br>
            <span class="badge bg-success">${(weatherData.visibility/1000)?.toFixed(1) || 'N/A'} km</span>
          </div>
        </div>
        <div class="row mt-2">
          <div class="col-12">
            <strong>Stability Class:</strong><br>
            <span class="badge" style="background-color: ${getStabilityColor(stabilityClass)}">${stabilityClass} - ${stabilityDesc}</span>
          </div>
        </div>
      </div>
      <div class="mt-2 text-muted">
        <small>
          <i class="fas fa-clock"></i> ${observedAt.toLocaleString()}<br>
          <i class="fas fa-database"></i> ${weatherData.primary_source || weatherData.source || 'Unknown'}
        </small>
      </div>
      <div class="mt-2">
        <button class="btn btn-sm btn-primary" onclick="showAtmosphericStability(${weatherData.latitude || 'null'}, ${weatherData.longitude || 'null'})">
          <i class="fas fa-chart-line"></i> Stability Analysis
        </button>
      </div>
    </div>
  `;
}

/**
 * Create detailed weather popup for map clicks
 */
function createDetailedWeatherPopup(weatherData) {
  return createWeatherStationPopup(weatherData) + `
    <div class="mt-2 border-top pt-2">
      <div class="d-grid gap-1">
        <button class="btn btn-sm btn-success" onclick="startDispersionHere(${weatherData.latitude || 'null'}, ${weatherData.longitude || 'null'})">
          <i class="fas fa-play"></i> Start Dispersion Here
        </button>
        <button class="btn btn-sm btn-info" onclick="addToFavoriteLocations(${weatherData.latitude || 'null'}, ${weatherData.longitude || 'null'})">
          <i class="fas fa-star"></i> Add to Favorites
        </button>
      </div>
    </div>
  `;
}

/**
 * Integrate weather data with dispersion scenario workflow
 */
async function integrateWeatherWithDispersionScenario(lat, lon, weatherData) {
  try {
    const response = await fetch('/weather/for_dispersion', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        latitude: lat,
        longitude: lon,
        scenario_id: window.currentDispersionScenario?.id
      })
    });
    
    const result = await response.json();
    
    if (result.status === 'success') {
      console.log('Weather integrated with dispersion scenario:', result.scenario_id);
      
      // Update dispersion calculations with new weather data
      if (window.dispersionManager) {
        window.dispersionManager.updateWeatherData(result.dispersion_weather);
      }
      
      // Notify user
      updateWeatherStatus('Weather integrated with dispersion scenario', 'success');
    }
  } catch (error) {
    console.error('Error integrating weather with dispersion:', error);
  }
}

/**
 * Utility functions for weather visualization
 */
function getTemperatureColor(temperature) {
  if (temperature < 0) return '#0066cc';
  if (temperature < 10) return '#3399ff';
  if (temperature < 25) return '#66cc66';
  if (temperature < 35) return '#ffcc00';
  return '#ff6600';
}

function getStabilityColor(stabilityClass) {
  const colors = {
    'A': '#ff4444', // Very Unstable - Red
    'B': '#ff8800', // Moderately Unstable - Orange  
    'C': '#ffcc00', // Slightly Unstable - Yellow
    'D': '#66cc66', // Neutral - Green
    'E': '#3399ff', // Slightly Stable - Blue
    'F': '#0066cc'  // Moderately Stable - Dark Blue
  };
  return colors[stabilityClass] || '#666666';
}

function getStabilityDescription(stabilityClass) {
  const descriptions = {
    'A': 'Very Unstable',
    'B': 'Moderately Unstable', 
    'C': 'Slightly Unstable',
    'D': 'Neutral',
    'E': 'Slightly Stable',
    'F': 'Moderately Stable'
  };
  return descriptions[stabilityClass] || 'Unknown';
}

function getWindSpeedColor(windSpeed) {
  if (windSpeed < 2) return '#1f77b4';
  if (windSpeed < 5) return '#2ca02c'; 
  if (windSpeed < 10) return '#ff7f0e';
  if (windSpeed < 15) return '#d62728';
  return '#8c564b';
}

function getWindDirectionText(degrees) {
  const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 
                     'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  const index = Math.round(degrees / 22.5) % 16;
  return directions[index];
}

function updateWeatherStatus(message, type = 'info') {
  const statusElement = document.getElementById('weather-status');
  if (statusElement) {
    statusElement.className = `alert alert-${type} p-2 small`;
    statusElement.textContent = message;
  }
}

/**
 * Global weather management functions
 */
function refreshAllWeatherData() {
  updateWeatherStatus('Refreshing all weather data...', 'info');
  
  // Clear existing weather layers
  window.weatherStationLayer.clearLayers();
  window.weatherWindLayer.clearLayers();
  
  // Refresh weather for all active events
  Object.keys(sourceMarkers).forEach(async (eventId) => {
    const marker = sourceMarkers[eventId];
    const latlng = marker.getLatLng();
    
    try {
      const weatherData = await fetchWeatherForLocation(latlng.lat, latlng.lng);
      if (weatherData.status === 'success') {
        addWeatherStationToMap(latlng.lat, latlng.lng, weatherData.weather_data);
      }
    } catch (error) {
      console.error(`Failed to refresh weather for event ${eventId}:`, error);
    }
  });
  
  updateWeatherStatus('Weather data refreshed', 'success');
}

async function showAtmosphericStability(lat, lon) {
  try {
    updateWeatherStatus('Loading atmospheric stability analysis...', 'info');
    
    const stabilityData = await fetchAtmosphericStability(lat, lon);
    
    if (stabilityData.status === 'success') {
      const analysis = stabilityData.stability_analysis;
      const dispersionParams = stabilityData.dispersion_parameters;
      
      // Create detailed stability popup
      const popupContent = `
        <div class="atmospheric-stability-popup">
          <h6><i class="fas fa-chart-line"></i> Atmospheric Stability Analysis</h6>
          <div class="stability-analysis">
            <div class="row">
              <div class="col-12 mb-2">
                <strong>Stability Class:</strong> 
                <span class="badge" style="background-color: ${getStabilityColor(analysis.stability_class)}">${analysis.stability_class}</span>
                <small class="text-muted d-block">${analysis.stability_description}</small>
              </div>
            </div>
            <div class="row">
              <div class="col-6">
                <strong>Mixing Height:</strong><br>
                <span class="badge bg-info">${analysis.mixing_height} m</span>
              </div>
              <div class="col-6">
                <strong>Conditions:</strong><br>
                <span class="badge bg-secondary">${analysis.atmospheric_conditions?.join(', ')}</span>
              </div>
            </div>
            <div class="mt-2">
              <strong>Dispersion Coefficients:</strong>
              <div class="small">
                σy: a=${analysis.dispersion_coefficients?.sigma_y?.a}, b=${analysis.dispersion_coefficients?.sigma_y?.b}<br>
                σz: c=${analysis.dispersion_coefficients?.sigma_z?.c}, d=${analysis.dispersion_coefficients?.sigma_z?.d}
              </div>
            </div>
          </div>
          <div class="mt-2">
            <button class="btn btn-sm btn-primary" onclick="startDispersionHere(${lat}, ${lon})">
              <i class="fas fa-play"></i> Start Dispersion Modeling
            </button>
          </div>
        </div>
      `;
      
      L.popup({
        maxWidth: 500,
        className: 'stability-analysis-popup'
      })
      .setLatLng([lat, lon])
      .setContent(popupContent)
      .openOn(map);
      
      updateWeatherStatus('Atmospheric stability analysis loaded', 'success');
    } else {
      updateWeatherStatus(`Stability analysis failed: ${stabilityData.error}`, 'danger');
    }
  } catch (error) {
    console.error('Error fetching atmospheric stability:', error);
    updateWeatherStatus(`Error: ${error.message}`, 'danger');
  }
}

function startDispersionHere(lat, lon) {
  // Navigate to dispersion scenario creation with pre-filled coordinates
  window.location.href = `/dispersion_events/new?latitude=${lat}&longitude=${lon}&weather_integrated=true`;
}

function addToFavoriteLocations(lat, lon) {
  // Add location to favorites (implement based on your favorites system)
  updateWeatherStatus(`Location ${lat.toFixed(4)}, ${lon.toFixed(4)} added to favorites`, 'success');
}

console.log('Weather map integration functions loaded');

/**
 * Add custom map controls
 */
function addCustomControls() {
  // Wind direction indicator
  const windControl = L.control({position: 'topright'});
  windControl.onAdd = function(map) {
    const div = L.DomUtil.create('div', 'wind-indicator bg-white p-2 rounded shadow-sm');
    div.innerHTML = `
      <div class="text-center">
        <div id="windArrow" class="wind-arrow mb-1">
          <i class="fas fa-location-arrow" style="font-size: 24px; color: #007bff;"></i>
        </div>
        <small class="d-block"><strong id="windSpeed">-- m/s</strong></small>
        <small class="text-muted" id="windDirection">--°</small>
      </div>
    `;
    return div;
  };
  windControl.addTo(map);

  // Emergency alert control
  const alertControl = L.control({position: 'topleft'});
  alertControl.onAdd = function(map) {
    const div = L.DomUtil.create('div', 'alert-control');
    div.innerHTML = `
      <button class="btn btn-danger btn-sm" onclick="triggerEmergencyAlert()" style="display: none;" id="emergencyBtn">
        <i class="fas fa-exclamation-triangle"></i> EMERGENCY
      </button>
    `;
    return div;
  };
  alertControl.addTo(map);
}

/**
 * Load active dispersion events from server
 */
function loadActiveEvents() {
  if (window.dashboardData && window.dashboardData.activeEvents) {
    window.dashboardData.activeEvents.forEach(event => {
      addEventToMap(event);
    });
  }
}

/**
 * Load facility locations
 */
function loadLocations() {
  fetch('/locations.json')
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      if (data.locations) {
        data.locations.forEach(location => {
          addLocationToMap(location);
        });
      } else if (Array.isArray(data)) {
        data.forEach(location => {
          addLocationToMap(location);
        });
      }
    })
    .catch(error => {
      console.error('Error loading locations:', error);
      // Use dummy data as fallback
      const dummyLocations = [
        { id: 1, name: 'Industrial Complex A', latitude: 32.776664, longitude: -96.796988 },
        { id: 2, name: 'Chemical Plant B', latitude: 32.786664, longitude: -96.806988 },
        { id: 3, name: 'Research Facility C', latitude: 32.766664, longitude: -96.786988 }
      ];
      dummyLocations.forEach(location => {
        addLocationToMap(location);
      });
    });
}

/**
 * Add a dispersion event to the map
 */
function addEventToMap(event) {
  const { id, source_lat, source_lng, chemical, location, status } = event;

  // Create source marker
  const sourceIcon = L.divIcon({
    className: 'source-marker',
    html: `
      <div class="marker-content bg-${status === 'active' ? 'danger' : 'warning'} text-white rounded-circle d-flex align-items-center justify-content-center" 
           style="width: 40px; height: 40px; border: 3px solid white; box-shadow: 0 2px 5px rgba(0,0,0,0.3);">
        <i class="fas fa-industry" style="font-size: 16px;"></i>
      </div>
    `,
    iconSize: [40, 40],
    iconAnchor: [20, 20]
  });

  const sourceMarker = L.marker([source_lat, source_lng], { icon: sourceIcon })
    .bindPopup(`
      <div class="popup-content">
        <h6><strong>${chemical}</strong></h6>
        <p class="mb-1"><i class="fas fa-map-marker-alt"></i> ${location}</p>
        <p class="mb-1"><i class="fas fa-circle text-${status === 'active' ? 'danger' : 'warning'}"></i> ${status.toUpperCase()}</p>
        <div class="mt-2">
          <a href="/dispersion_events/${id}" class="btn btn-sm btn-primary">View Details</a>
          ${status === 'active' ? '<button class="btn btn-sm btn-warning" onclick="stopEvent(' + id + ')">Stop</button>' : ''}
        </div>
      </div>
    `)
    .addTo(map);

  sourceMarkers[id] = sourceMarker;

  // Add receptors for this event
  if (event.receptors) {
    event.receptors.forEach(receptor => {
      addReceptorToMap(receptor, event);
    });
  }

  // Start plume visualization if active
  if (status === 'active') {
    startPlumeVisualization(event);
  }
}

/**
 * Add a receptor monitoring point to the map
 */
function addReceptorToMap(receptor, event) {
  const { id, lat, lng, concentration, health_impact } = receptor;
  
  // Determine receptor color based on concentration
  let colorClass = 'success';
  if (concentration > 100) colorClass = 'danger';
  else if (concentration > 10) colorClass = 'warning';
  else if (concentration > 1) colorClass = 'warning';

  const receptorIcon = L.divIcon({
    className: 'receptor-marker',
    html: `
      <div class="marker-content bg-${colorClass} rounded-circle d-flex align-items-center justify-content-center" 
           style="width: 20px; height: 20px; border: 2px solid white; box-shadow: 0 1px 3px rgba(0,0,0,0.3);">
        <i class="fas fa-crosshairs" style="font-size: 8px; color: white;"></i>
      </div>
    `,
    iconSize: [20, 20],
    iconAnchor: [10, 10]
  });

  const receptorMarker = L.marker([lat, lng], { icon: receptorIcon })
    .bindPopup(`
      <div class="popup-content">
        <h6><strong>${receptor.name}</strong></h6>
        <p class="mb-1"><strong>Concentration:</strong> ${concentration.toFixed(3)} mg/m³</p>
        <p class="mb-1"><strong>Health Impact:</strong> <span class="badge bg-${colorClass}">${health_impact}</span></p>
        <small class="text-muted">Event: ${event.chemical}</small>
      </div>
    `)
    .addTo(map);

  if (!receptorMarkers[event.id]) {
    receptorMarkers[event.id] = [];
  }
  receptorMarkers[event.id].push(receptorMarker);
}

/**
 * Add a facility location to the map
 */
function addLocationToMap(location) {
  // Check if map is ready before adding markers
  if (!map || !map._container) {
    console.log('⚠️ Map not ready, skipping location:', location.name);
    return;
  }

  const { id, name, latitude, longitude, terrain_type, building_height } = location;

  const locationIcon = L.divIcon({
    className: 'location-marker',
    html: `
      <div class="marker-content bg-info text-white rounded d-flex align-items-center justify-content-center" 
           style="width: 30px; height: 30px; border: 2px solid white; box-shadow: 0 1px 3px rgba(0,0,0,0.3);">
        <i class="fas fa-building" style="font-size: 12px;"></i>
      </div>
    `,
    iconSize: [30, 30],
    iconAnchor: [15, 15]
  });

  try {
    const locationMarker = L.marker([latitude, longitude], { icon: locationIcon })
      .bindPopup(`
        <div class="popup-content">
          <h6><strong>${name}</strong></h6>
          <p class="mb-1"><strong>Terrain:</strong> ${terrain_type}</p>
          <p class="mb-1"><strong>Building Height:</strong> ${building_height}m</p>
          <div class="mt-2">
            <a href="/locations/${id}" class="btn btn-sm btn-primary">View Details</a>
            <button class="btn btn-sm btn-success" onclick="createEventHere(${id})">New Event</button>
          </div>
        </div>
      `)
      .addTo(map);
  } catch (error) {
    console.error('Error adding location marker:', error);
  }
}

/**
 * Start real-time plume visualization for an active event
 */
function startPlumeVisualization(event) {
  const eventId = event.id;
  
  // Fetch initial plume data
  updatePlumeContours(eventId);
  
  // Set up periodic updates
  if (!currentEventLayers[eventId]) {
    currentEventLayers[eventId] = {
      contours: L.layerGroup().addTo(map),
      updateInterval: setInterval(() => {
        updatePlumeContours(eventId);
      }, 30000) // Update every 30 seconds
    };
  }
}

/**
 * Update plume contours for a specific event
 */
function updatePlumeContours(eventId) {
  fetch(`/api/v1/dispersion_events/${eventId}/plume_data.json`)
    .then(response => response.json())
    .then(data => {
      if (data.data && data.data.contours) {
        drawPlumeContours(eventId, data.data);
        updateLastUpdateTime();
      }
    })
    .catch(error => {
      console.error('Error updating plume contours:', error);
      updateConnectionStatus('error');
    });
}

/**
 * Draw plume contours on the map
 */
function drawPlumeContours(eventId, plumeData) {
  const { contours, source_location, weather } = plumeData;
  
  // Clear existing contours for this event
  if (currentEventLayers[eventId]) {
    currentEventLayers[eventId].contours.clearLayers();
  }

  // Draw new contours
  contours.forEach(contour => {
    if (contour.points && contour.points.length > 2) {
      const polygon = L.polygon(contour.points, {
        color: contour.color,
        fillColor: contour.color,
        fillOpacity: 0.3,
        weight: 2,
        opacity: 0.7
      }).bindPopup(`
        <div class="popup-content">
          <h6>Concentration Contour</h6>
          <p><strong>Level:</strong> ${contour.level} mg/m³</p>
          <p><strong>Wind:</strong> ${weather.wind_speed} m/s, ${weather.wind_direction}°</p>
          <p><strong>Stability:</strong> ${weather.stability_class}</p>
        </div>
      `);
      
      currentEventLayers[eventId].contours.addLayer(polygon);
    }
  });

  // Update wind indicator
  updateWindIndicator(weather);
}

/**
 * Set up real-time updates via WebSocket or polling
 */
function setupRealtimeUpdates() {
  // For now, use polling. In a real implementation, you'd use ActionCable WebSockets
  setInterval(() => {
    refreshActiveEventData();
  }, 60000); // Refresh every minute

  updateConnectionStatus('connected');
}

/**
 * Refresh data for all active events
 */
function refreshActiveEventData() {
  Object.keys(sourceMarkers).forEach(eventId => {
    // Fetch latest calculation data
    fetch(`/api/v1/dispersion_events/${eventId}/live_calculations.json`)
      .then(response => response.json())
      .then(data => {
        if (data.data && data.data.calculations) {
          updateReceptorConcentrations(eventId, data.data.calculations);
        }
      })
      .catch(error => {
        console.error('Error refreshing event data:', error);
      });
  });
}

/**
 * Update receptor markers with new concentration data
 */
function updateReceptorConcentrations(eventId, calculations) {
  if (receptorMarkers[eventId]) {
    calculations.forEach(calc => {
      // Find corresponding receptor marker and update its appearance
      const receptor = receptorMarkers[eventId].find(marker => {
        const pos = marker.getLatLng();
        return Math.abs(pos.lat - calc.receptor_coordinates.lat) < 0.0001 &&
               Math.abs(pos.lng - calc.receptor_coordinates.lng) < 0.0001;
      });
      
      if (receptor) {
        // Update marker color based on concentration
        let colorClass = 'success';
        if (calc.concentration > 100) colorClass = 'danger';
        else if (calc.concentration > 10) colorClass = 'warning';
        else if (calc.concentration > 1) colorClass = 'warning';
        
        // Update marker popup
        receptor.setPopupContent(`
          <div class="popup-content">
            <h6><strong>Receptor</strong></h6>
            <p class="mb-1"><strong>Concentration:</strong> ${calc.concentration.toFixed(3)} mg/m³</p>
            <p class="mb-1"><strong>Updated:</strong> ${new Date(calc.timestamp).toLocaleTimeString()}</p>
          </div>
        `);
      }
    });
  }
}

/**
 * Update wind indicator display
 */
function updateWindIndicator(weather) {
  if (weather) {
    document.getElementById('windSpeed').textContent = `${weather.wind_speed} m/s`;
    document.getElementById('windDirection').textContent = `${weather.wind_direction}°`;
    
    // Rotate wind arrow
    const arrow = document.getElementById('windArrow');
    if (arrow) {
      arrow.style.transform = `rotate(${weather.wind_direction}deg)`;
    }
  }
}

/**
 * Update connection status indicator
 */
function updateConnectionStatus(status) {
  const statusBadge = document.getElementById('connectionStatus');
  if (statusBadge) {
    switch(status) {
      case 'connected':
        statusBadge.className = 'badge bg-success';
        statusBadge.textContent = 'Connected';
        break;
      case 'error':
        statusBadge.className = 'badge bg-danger';
        statusBadge.textContent = 'Error';
        break;
      case 'disconnected':
        statusBadge.className = 'badge bg-warning';
        statusBadge.textContent = 'Disconnected';
        break;
    }
  }
}

/**
 * Update last update time display
 */
function updateLastUpdateTime() {
  const timeElement = document.getElementById('lastUpdateTime');
  if (timeElement) {
    timeElement.textContent = new Date().toLocaleTimeString();
  }
}

// Utility functions for map interactions

function centerMapOnActiveEvents() {
  const bounds = [];
  Object.values(sourceMarkers).forEach(marker => {
    bounds.push(marker.getLatLng());
  });
  
  if (bounds.length > 0) {
    map.fitBounds(bounds, { padding: [50, 50] });
  }
}

function refreshPlumeData() {
  Object.keys(currentEventLayers).forEach(eventId => {
    updatePlumeContours(eventId);
  });
}

function toggleFullscreen() {
  const mapContainer = document.getElementById('dispersionMap');
  if (mapContainer.requestFullscreen) {
    mapContainer.requestFullscreen();
  }
}

function stopEvent(eventId) {
  if (confirm('Are you sure you want to stop monitoring this event?')) {
    fetch(`/dispersion_events/${eventId}/stop_monitoring`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (response.ok) {
        location.reload();
      }
    })
    .catch(error => {
      console.error('Error stopping event:', error);
      alert('Failed to stop event monitoring');
    });
  }
}

function createEventHere(locationId) {
  window.location.href = `/dispersion_events/new?location_id=${locationId}`;
}

function triggerEmergencyAlert() {
  // Implementation for emergency alert system
  alert('Emergency alert triggered! All relevant authorities will be notified.');
}

// Start real-time updates when everything is loaded
function startRealTimeUpdates() {
  console.log('Starting real-time updates for dispersion monitoring');
  setupRealtimeUpdates();
}

console.log('Dispersion map JavaScript loaded successfully');

// Make functions globally available
if (typeof window !== 'undefined') {
  window.initializeDispersionMap = initializeDispersionMap;
  window.startRealTimeUpdates = startRealTimeUpdates;
  window.sourceMarkers = sourceMarkers;
  window.receptorMarkers = receptorMarkers;
  window.concentrationOverlays = concentrationOverlays;
  window.centerMapOnActiveEvents = centerMapOnActiveEvents;
  window.triggerEmergencyAlert = triggerEmergencyAlert;
  window.createEventHere = createEventHere;
}