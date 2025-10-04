// JavaScript Module Integration Test
// Tests that all modules load correctly and can communicate

function testModuleIntegration() {
  console.log('🔄 Testing JavaScript Module Integration...');
  console.log('=' * 50);
  
  const tests = [
    {
      name: 'Map Container Exists',
      test: () => !!document.getElementById('dispersionMap')
    },
    {
      name: 'Leaflet Library Loaded', 
      test: () => typeof L !== 'undefined'
    },
    {
      name: 'Dispersion Map Initialized',
      test: () => !!(window.dispersionMap || window.map)
    },
    {
      name: 'Real-time Manager Available',
      test: () => !!window.realTimeManager
    },
    {
      name: 'Weather Manager Available', 
      test: () => !!window.weatherManager
    },
    {
      name: 'ActionCable Connection',
      test: () => !!(window.App && window.App.cable)
    },
    {
      name: 'Map Has Layers',
      test: () => {
        const map = window.dispersionMap || window.map;
        return map && Object.keys(map._layers || {}).length > 0;
      }
    }
  ];
  
  let passed = 0;
  let failed = 0;
  
  tests.forEach(test => {
    try {
      const result = test.test();
      console.log(`${test.name}: ${result ? '✅ PASS' : '❌ FAIL'}`);
      result ? passed++ : failed++;
    } catch (e) {
      console.log(`${test.name}: ❌ ERROR - ${e.message}`);
      failed++;
    }
  });
  
  console.log('=' * 50);
  console.log(`Results: ${passed} passed, ${failed} failed`);
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