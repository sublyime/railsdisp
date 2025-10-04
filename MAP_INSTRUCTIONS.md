# 🗺️ Interactive Map Instructions

## How to Access the Interactive Map

1. **Go to the Dashboard**: Click "Dashboard" in the navigation bar or visit: http://localhost:3000/dashboard

2. **Interactive Map Features**:
   - **Click anywhere on the map** to get weather data for that location
   - **View dispersion plumes** from active events automatically
   - **Control map layers** using the layer control in the top-right
   - **Zoom and pan** to explore different areas

## Map Functionality

### 🌦️ **Weather Data on Click**
- Click any location on the map
- Get real-time or generated weather data including:
  - Temperature
  - Wind speed and direction  
  - Humidity and atmospheric pressure
  - Stability class
- Weather stations appear as markers with detailed popups

### 🌪️ **Dispersion Plumes**
- Active dispersion events automatically show plumes
- Color-coded concentration levels:
  - 🟢 Green (0.1 mg/m³) - Safe
  - 🟡 Yellow (1.0 mg/m³) - Caution
  - 🟠 Orange (10.0 mg/m³) - Warning
  - 🔴 Red (100+ mg/m³) - Danger

### 🎛️ **Map Controls**
- **Layer Control**: Switch between Street, Satellite, and Topographic views
- **Weather Controls**: Enable/disable weather click functionality
- **Plume Controls**: Show/hide dispersion plumes and receptors
- **Real-time Controls**: Manage live updates and data refresh

### 📍 **Event Markers**
- Source locations show as red markers
- Receptor points show as small blue circles
- Click markers for detailed information

## Current Status

✅ **Working Features**:
- Interactive map with multiple base layers
- Click-to-get-weather functionality
- Automatic plume visualization for active events  
- Real-time updates and controls
- Responsive design with control panels

🔧 **Available Data**:
- 5 Events created (including the one you just made!)
- 200+ Receptors for dispersion modeling
- 5 Chemical types and 5 Locations
- Weather integration system

## Quick Start

1. Visit: http://localhost:3000/dashboard
2. Wait for map to load (look for "Map initialized successfully" in console)
3. Click anywhere on the map to get weather data
4. View existing dispersion plumes from created events
5. Use the control panel on the left to manage the display

## Troubleshooting

If the map doesn't load:
1. Check the browser console for JavaScript errors
2. Ensure you're on the dashboard page (not the individual event page)
3. Wait a few seconds for initialization
4. Refresh the page if needed

The map system is designed to handle missing data gracefully and will generate realistic mock weather data if no real data is available for a clicked location.