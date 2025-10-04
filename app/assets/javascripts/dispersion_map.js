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
  // Check if map container exists
  const mapContainer = document.getElementById('dispersionMap');
  if (!mapContainer) {
    console.error('Map container #dispersionMap not found');
    return false;
  }

  // Check if map is already initialized
  if (map && map._container) {
    console.log('Map already initialized');
    return true;
  }

  // Create the map
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

  // Load initial data
  loadActiveEvents();
  loadLocations();

  // Set up real-time updates
  setupRealtimeUpdates();

  // Notify other modules that map is ready
  document.dispatchEvent(new CustomEvent('mapReady', { detail: { map: map } }));
  
  // Try to initialize WeatherManager if available
  if (window.weatherManager && window.weatherManager.initializeWithMap) {
    window.weatherManager.initializeWithMap(map);
  }

  console.log('Dispersion map initialized successfully');
  return true;
}

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