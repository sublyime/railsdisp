// JavaScript Module Integration Test
// Tests that all modules load correctly and can communicate

function testModuleIntegration() {
  console.log('🔄 Testing JavaScript Module Integration...');
  console.log('=' * 50);
  
  // First check if we're on a page that should have a map
  const hasMapContainer = !!document.getElementById('dispersionMap');
  const pageName = hasMapContainer ? 'Dashboard' : 'Other Page';
  
  console.log(`📄 Detected page type: ${pageName}`);
  
  const tests = [
    {
      name: 'Map Container Exists',
      test: () => !!document.getElementById('dispersionMap'),
      required: false, // Not required on all pages
      description: hasMapContainer ? 'Found on dashboard' : 'Not required on this page'
    },
    {
      name: 'Leaflet Library Loaded', 
      test: () => typeof L !== 'undefined',
      required: true,
      description: 'Required for map functionality'
    },
    {
      name: 'Dispersion Map Initialized',
      test: () => !!(window.dispersionMap || window.map),
      required: hasMapContainer, // Only required if container exists
      description: hasMapContainer ? 'Should be initialized on dashboard' : 'Not needed on this page'
    },
    {
      name: 'Real-time Manager Available',
      test: () => !!window.realTimeManager,
      required: false,
      description: 'Optional - for real-time updates'
    },
    {
      name: 'Weather Manager Available', 
      test: () => !!window.weatherManager,
      required: false,
      description: 'Optional - for weather integration'
    },
    {
      name: 'ActionCable Connection',
      test: () => !!(window.App && window.App.cable),
      required: false,
      description: 'Optional - for WebSocket updates'
    },
    {
      name: 'Map Has Layers',
      test: () => {
        const map = window.dispersionMap || window.map;
        return map && Object.keys(map._layers || {}).length > 0;
      },
      required: hasMapContainer,
      description: hasMapContainer ? 'Map should have base layers' : 'Not applicable'
    }
  ];
  
  let passed = 0;
  let failed = 0;
  let warnings = 0;
  
  tests.forEach(test => {
    try {
      const result = test.test();
      if (result) {
        console.log(`${test.name}: ✅ PASS`);
        passed++;
      } else if (test.required) {
        console.log(`${test.name}: ❌ FAIL - ${test.description}`);
        failed++;
      } else {
        console.log(`${test.name}: ⚠️ SKIP - ${test.description}`);
        warnings++;
      }
    } catch (e) {
      if (test.required) {
        console.log(`${test.name}: ❌ ERROR - ${e.message}`);
        failed++;
      } else {
        console.log(`${test.name}: ⚠️ SKIP - ${e.message}`);
        warnings++;
      }
    }
  });
  
  console.log('=' * 50);
  console.log(`Results: ${passed} passed, ${failed} failed, ${warnings} skipped`);
  console.log(`Success rate: ${(passed / (passed + failed) * 100).toFixed(1)}%`);
  
  return {
    passed,
    failed,
    successRate: passed / (passed + failed) * 100
  };
}

// Auto-run test when page loads
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    setTimeout(testModuleIntegration, 2000); // Wait 2 seconds for modules to load
  });
} else {
  setTimeout(testModuleIntegration, 2000);
}

// Make test available globally
window.testModuleIntegration = testModuleIntegration;