// Real-time Dispersion Manager
// Handles WebSocket connections for live plume updates and dispersion calculations

class RealTimeDispersionManager {
  constructor(map) {
    this.map = map;
    this.dispersionChannel = null;
    this.activeEventSubscriptions = new Map();
    this.updateInterval = 30000; // 30 seconds
    this.lastUpdateTime = new Map();
    
    this.initializeDispersionChannel();
    this.setupRealTimeControls();
  }

  // Initialize ActionCable connection for real-time dispersion updates
  initializeDispersionChannel() {
    if (typeof window.createCableSubscription === 'function') {
      window.createCableSubscription("DispersionEventsChannel", {
        connected: () => {
          console.log('Connected to DispersionEventsChannel');
          this.onConnected();
        },

        disconnected: () => {
          console.log('Disconnected from DispersionEventsChannel');
          this.onDisconnected();
        },

        received: (data) => {
          this.handleDispersionUpdate(data);
        },

        subscribeToEvent: (eventId) => {
          this.perform('subscribe_to_event', { event_id: eventId });
        },

        unsubscribeFromEvent: (eventId) => {
          this.perform('unsubscribe_from_event', { event_id: eventId });
        },

        requestCalculationUpdate: (eventId) => {
          this.perform('request_calculation_update', { event_id: eventId });
        }
      }).then(subscription => {
        this.dispersionChannel = subscription;
      });
    } else {
      console.log('ActionCable not available, using polling for dispersion updates');
      this.setupPollingFallback();
    }
  }

  // Handle connection established
  onConnected() {
    // Subscribe to all active events
    if (window.dashboardData && window.dashboardData.activeEvents) {
      window.dashboardData.activeEvents.forEach(event => {
        this.subscribeToEvent(event.id);
      });
    }
  }

  // Handle connection lost
  onDisconnected() {
    console.warn('Real-time connection lost, switching to polling mode');
    this.setupPollingFallback();
  }

  // Subscribe to specific event updates
  subscribeToEvent(eventId) {
    if (this.dispersionChannel) {
      this.dispersionChannel.subscribeToEvent(eventId);
      this.activeEventSubscriptions.set(eventId, true);
      console.log(`Subscribed to event ${eventId} updates`);
    }
  }

  // Unsubscribe from event updates
  unsubscribeFromEvent(eventId) {
    if (this.dispersionChannel) {
      this.dispersionChannel.unsubscribeFromEvent(eventId);
      this.activeEventSubscriptions.delete(eventId);
      console.log(`Unsubscribed from event ${eventId} updates`);
    }
  }

  // Request immediate calculation update
  requestCalculationUpdate(eventId) {
    if (this.dispersionChannel) {
      this.dispersionChannel.requestCalculationUpdate(eventId);
      console.log(`Requested calculation update for event ${eventId}`);
    } else {
      // Fallback to direct API call
      this.performCalculationUpdate(eventId);
    }
  }

  // Handle incoming dispersion data updates
  handleDispersionUpdate(data) {
    console.log('Received dispersion update:', data);

    switch (data.type) {
      case 'active_events':
        this.updateActiveEvents(data.events);
        break;
      case 'event_update':
        this.updateEventVisualization(data.event);
        break;
      case 'calculation_complete':
        this.updatePlumeVisualization(data.event_id, data.calculation);
        break;
      case 'weather_update':
        this.updateWeatherVisualization(data);
        break;
      default:
        console.log('Unknown update type:', data.type);
    }

    // Update last update time
    this.lastUpdateTime.set(data.event_id || 'global', new Date());
  }

  // Update active events on map
  updateActiveEvents(events) {
    events.forEach(event => {
      this.updateEventMarker(event);
      this.updatePlumeContours(event);
    });
  }

  // Update individual event visualization
  updateEventVisualization(event) {
    this.updateEventMarker(event);
    this.updatePlumeContours(event);
    this.updateReceptors(event);
  }

  // Update event marker on map
  updateEventMarker(event) {
    if (!window.eventMarkers) window.eventMarkers = new Map();

    let marker = window.eventMarkers.get(event.id);
    
    if (!marker) {
      // Create new marker
      marker = L.marker([event.source_coordinates.lat, event.source_coordinates.lng], {
        icon: this.createEventIcon(event)
      }).addTo(this.map);
      
      window.eventMarkers.set(event.id, marker);
    } else {
      // Update existing marker
      marker.setIcon(this.createEventIcon(event));
    }

    // Update popup content
    const popupContent = this.createEventPopup(event);
    marker.bindPopup(popupContent);
  }

  // Update plume contours for event
  updatePlumeContours(event) {
    // Get latest plume data
    fetch(`/api/v1/dispersion_events/${event.id}/plume_data.json`)
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.renderPlumeContours(event.id, data.data.contours);
        }
      })
      .catch(error => {
        console.error('Error fetching plume data:', error);
      });
  }

  // Render plume contours on map
  renderPlumeContours(eventId, contours) {
    if (!window.plumeContours) window.plumeContours = new Map();

    // Remove existing contours for this event
    const existingContours = window.plumeContours.get(eventId);
    if (existingContours) {
      existingContours.forEach(contour => this.map.removeLayer(contour));
    }

    // Add new contours
    const newContours = [];
    contours.forEach(contourData => {
      const contour = L.polygon(contourData.coordinates, {
        color: contourData.color || this.getConcentrationColor(contourData.concentration),
        fillColor: contourData.color || this.getConcentrationColor(contourData.concentration),
        fillOpacity: 0.3,
        weight: 2
      }).addTo(this.map);

      contour.bindPopup(`
        <div class="plume-popup">
          <h6>Concentration Contour</h6>
          <p><strong>Level:</strong> ${contourData.concentration} mg/m³</p>
          <p><strong>Risk:</strong> ${contourData.level}</p>
        </div>
      `);

      newContours.push(contour);
    });

    window.plumeContours.set(eventId, newContours);
  }

  // Update receptor markers and concentrations
  updateReceptors(event) {
    if (!window.receptorMarkers) window.receptorMarkers = new Map();

    event.receptors.forEach(receptor => {
      let marker = window.receptorMarkers.get(receptor.id);
      
      if (!marker) {
        marker = L.marker([receptor.coordinates.lat, receptor.coordinates.lng], {
          icon: this.createReceptorIcon(receptor)
        }).addTo(this.map);
        
        window.receptorMarkers.set(receptor.id, marker);
      } else {
        marker.setIcon(this.createReceptorIcon(receptor));
      }

      // Update popup
      const popupContent = this.createReceptorPopup(receptor);
      marker.bindPopup(popupContent);
    });
  }

  // Create event marker icon
  createEventIcon(event) {
    const color = this.getEventStatusColor(event.status);
    return L.divIcon({
      html: `<i class="fas fa-industry" style="color: ${color}; font-size: 20px;"></i>`,
      className: 'event-marker-icon',
      iconSize: [24, 24],
      iconAnchor: [12, 12]
    });
  }

  // Create receptor marker icon
  createReceptorIcon(receptor) {
    const color = this.getHealthImpactColor(receptor.health_impact);
    return L.divIcon({
      html: `<i class="fas fa-crosshairs" style="color: ${color}; font-size: 16px;"></i>`,
      className: 'receptor-marker-icon',
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });
  }

  // Create event popup content
  createEventPopup(event) {
    return `
      <div class="event-popup">
        <h6><i class="fas fa-industry"></i> ${event.chemical_name}</h6>
        <p><strong>Location:</strong> ${event.location_name}</p>
        <p><strong>Status:</strong> <span class="badge bg-${this.getEventStatusBadge(event.status)}">${event.status}</span></p>
        <p><strong>Release Rate:</strong> ${event.release_rate} kg/s</p>
        ${event.latest_calculation ? `
          <p><strong>Max Concentration:</strong> ${event.latest_calculation.max_concentration} mg/m³</p>
          <p><strong>Last Updated:</strong> ${new Date(event.latest_calculation.timestamp).toLocaleTimeString()}</p>
        ` : ''}
        <button class="btn btn-primary btn-sm" onclick="window.realTimeManager.requestCalculationUpdate(${event.id})">
          <i class="fas fa-sync"></i> Update
        </button>
      </div>
    `;
  }

  // Create receptor popup content
  createReceptorPopup(receptor) {
    return `
      <div class="receptor-popup">
        <h6><i class="fas fa-crosshairs"></i> ${receptor.name}</h6>
        <p><strong>Concentration:</strong> ${receptor.concentration.toFixed(3)} mg/m³</p>
        <p><strong>Health Impact:</strong> <span class="badge bg-${this.getHealthImpactBadge(receptor.health_impact)}">${receptor.health_impact}</span></p>
        <p><strong>Coordinates:</strong> ${receptor.coordinates.lat.toFixed(4)}, ${receptor.coordinates.lng.toFixed(4)}</p>
      </div>
    `;
  }

  // Color mapping functions
  getEventStatusColor(status) {
    const colors = {
      'active': '#dc3545',
      'monitoring': '#fd7e14',
      'inactive': '#6c757d',
      'completed': '#198754'
    };
    return colors[status] || '#6c757d';
  }

  getEventStatusBadge(status) {
    const badges = {
      'active': 'danger',
      'monitoring': 'warning',
      'inactive': 'secondary',
      'completed': 'success'
    };
    return badges[status] || 'secondary';
  }

  getHealthImpactColor(impact) {
    const colors = {
      'safe': '#198754',
      'low': '#20c997',
      'caution': '#ffc107',
      'warning': '#fd7e14',
      'danger': '#dc3545',
      'unknown': '#6c757d'
    };
    return colors[impact] || '#6c757d';
  }

  getHealthImpactBadge(impact) {
    const badges = {
      'safe': 'success',
      'low': 'info',
      'caution': 'warning',
      'warning': 'warning',
      'danger': 'danger',
      'unknown': 'secondary'
    };
    return badges[impact] || 'secondary';
  }

  getConcentrationColor(concentration) {
    if (concentration >= 10) return '#dc3545';
    if (concentration >= 1) return '#fd7e14';
    if (concentration >= 0.1) return '#ffc107';
    return '#198754';
  }

  // Setup real-time control panel
  setupRealTimeControls() {
    const controlPanel = document.getElementById('real-time-controls');
    if (!controlPanel) return;

    // Auto-update toggle
    const autoUpdateToggle = document.createElement('div');
    autoUpdateToggle.className = 'form-check mb-2';
    autoUpdateToggle.innerHTML = `
      <input class="form-check-input" type="checkbox" id="autoUpdate" checked>
      <label class="form-check-label" for="autoUpdate">
        Auto-update (30s)
      </label>
    `;
    controlPanel.appendChild(autoUpdateToggle);

    document.getElementById('autoUpdate').onchange = (e) => {
      if (e.target.checked) {
        this.startAutoUpdate();
      } else {
        this.stopAutoUpdate();
      }
    };

    // Manual update button
    const updateButton = document.createElement('button');
    updateButton.className = 'btn btn-primary btn-sm w-100 mb-2';
    updateButton.innerHTML = '<i class="fas fa-sync"></i> Update Now';
    updateButton.onclick = () => this.updateAllEvents();
    controlPanel.appendChild(updateButton);

    // Start auto-update by default
    this.startAutoUpdate();
  }

  // Auto-update management
  startAutoUpdate() {
    this.stopAutoUpdate(); // Clear any existing interval
    
    this.autoUpdateInterval = setInterval(() => {
      this.updateAllEvents();
    }, this.updateInterval);
    
    console.log('Auto-update started (30s interval)');
  }

  stopAutoUpdate() {
    if (this.autoUpdateInterval) {
      clearInterval(this.autoUpdateInterval);
      this.autoUpdateInterval = null;
      console.log('Auto-update stopped');
    }
  }

  // Update all active events
  updateAllEvents() {
    this.activeEventSubscriptions.forEach((_, eventId) => {
      this.requestCalculationUpdate(eventId);
    });
  }

  // Fallback polling mechanism
  setupPollingFallback() {
    setInterval(() => {
      this.updateAllEvents();
    }, this.updateInterval);
  }

  // Direct API calculation update (fallback)
  performCalculationUpdate(eventId) {
    fetch(`/api/v1/dispersion_events/${eventId}/live_calculations.json`)
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.handleDispersionUpdate({
            type: 'calculation_complete',
            event_id: eventId,
            calculation: data.data
          });
        }
      })
      .catch(error => {
        console.error('Error updating calculations:', error);
      });
  }

  // Clean up resources
  destroy() {
    this.stopAutoUpdate();
    
    if (this.dispersionChannel) {
      this.dispersionChannel.unsubscribe();
    }
    
    // Clean up map layers
    if (window.eventMarkers) {
      window.eventMarkers.forEach(marker => this.map.removeLayer(marker));
    }
    
    if (window.plumeContours) {
      window.plumeContours.forEach(contours => {
        contours.forEach(contour => this.map.removeLayer(contour));
      });
    }
  }
}

// Initialize real-time manager when map is ready
document.addEventListener('DOMContentLoaded', function() {
  // Wait for map to be initialized
  const checkMapAndStart = () => {
    if (window.dispersionMap) {
      window.realTimeManager = new RealTimeDispersionManager(window.dispersionMap);
      console.log('Real-time dispersion manager initialized');
    } else {
      setTimeout(checkMapAndStart, 100);
    }
  };
  
  setTimeout(checkMapAndStart, 1000); // Wait a bit for other scripts to load
});

// Make RealTimeDispersionManager globally available
if (typeof window !== 'undefined') {
  window.RealTimeDispersionManager = RealTimeDispersionManager;
}