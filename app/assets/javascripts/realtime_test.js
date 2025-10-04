// Test Real-time Dispersion Updates
// This script tests the WebSocket connections and real-time plume updates

class RealTimeTest {
  constructor() {
    this.testResults = [];
    this.testCount = 0;
    this.passedCount = 0;
    
    console.log('Starting Real-time Dispersion System Tests...');
    this.runTests();
  }

  async runTests() {
    // Test 1: Check if ActionCable is available
    await this.testActionCableAvailability();
    
    // Test 2: Test API endpoints
    await this.testAPIEndpoints();
    
    // Test 3: Test WebSocket connections
    await this.testWebSocketConnections();
    
    // Test 4: Test real-time data flow
    await this.testRealTimeDataFlow();
    
    // Show results
    this.showTestResults();
  }

  async testActionCableAvailability() {
    this.testCount++;
    const testName = 'ActionCable Availability';
    
    try {
      if (typeof ActionCable !== 'undefined') {
        this.logTest(testName, 'PASS', 'ActionCable is available globally');
        this.passedCount++;
      } else {
        this.logTest(testName, 'FAIL', 'ActionCable not found in global scope');
      }
    } catch (error) {
      this.logTest(testName, 'ERROR', error.message);
    }
  }

  async testAPIEndpoints() {
    this.testCount++;
    const testName = 'API Endpoints';
    
    try {
      // First test the dispersion events list endpoint
      const listResponse = await fetch('/api/v1/dispersion_events.json');
      
      if (listResponse.ok) {
        const listData = await listResponse.json();
        if (listData.status === 'success') {
          // Test plume data with first available event or use ID 1
          const eventId = listData.data?.length > 0 ? listData.data[0].id : 1;
          const plumeResponse = await fetch(`/api/v1/dispersion_events/${eventId}/plume_data.json`);
          
          if (plumeResponse.ok) {
            const plumeData = await plumeResponse.json();
            if (plumeData.status === 'success' && plumeData.data) {
              this.logTest(testName, 'PASS', `API endpoints responding correctly (Event ${eventId})`);
              this.passedCount++;
            } else {
              this.logTest(testName, 'FAIL', 'Invalid plume API response format');
            }
          } else {
            this.logTest(testName, 'FAIL', `Plume API responded with status ${plumeResponse.status}`);
          }
        } else {
          this.logTest(testName, 'FAIL', 'Invalid events list API response format');
        }
      } else {
        this.logTest(testName, 'FAIL', `Events list API responded with status ${listResponse.status}`);
      }
    } catch (error) {
      this.logTest(testName, 'ERROR', error.message);
    }
  }

  async testWebSocketConnections() {
    this.testCount++;
    const testName = 'WebSocket Connections';
    
    try {
      if (window.ActionCableManager) {
        const isConnected = window.ActionCableManager.isConnected();
        if (isConnected) {
          this.logTest(testName, 'PASS', 'ActionCable connection is active');
          this.passedCount++;
        } else {
          this.logTest(testName, 'WARN', 'ActionCable connection not active, using fallback');
        }
      } else {
        this.logTest(testName, 'FAIL', 'ActionCableManager not initialized');
      }
    } catch (error) {
      this.logTest(testName, 'ERROR', error.message);
    }
  }

  async testRealTimeDataFlow() {
    this.testCount++;
    const testName = 'Real-time Data Flow';
    
    try {
      // Test if real-time manager is initialized
      if (window.realTimeManager) {
        this.logTest(testName, 'PASS', 'Real-time manager is initialized');
        this.passedCount++;
        
        // Test subscription to dispersion events
        if (window.realTimeManager.dispersionSubscription) {
          console.log('✓ Dispersion subscription active');
        } else {
          console.log('⚠ Dispersion subscription not found');
        }
      } else {
        this.logTest(testName, 'FAIL', 'Real-time manager not found');
      }
    } catch (error) {
      this.logTest(testName, 'ERROR', error.message);
    }
  }

  logTest(testName, status, message) {
    const result = { testName, status, message };
    this.testResults.push(result);
    
    const statusIcon = {
      'PASS': '✅',
      'FAIL': '❌', 
      'WARN': '⚠️',
      'ERROR': '💥'
    }[status];
    
    console.log(`${statusIcon} ${testName}: ${message}`);
  }

  showTestResults() {
    console.log('\n=== Real-time Dispersion System Test Results ===');
    console.log(`Total Tests: ${this.testCount}`);
    console.log(`Passed: ${this.passedCount}`);
    console.log(`Failed: ${this.testCount - this.passedCount}`);
    console.log(`Success Rate: ${((this.passedCount / this.testCount) * 100).toFixed(1)}%`);
    
    if (this.passedCount === this.testCount) {
      console.log('🎉 All tests passed! Real-time system is working correctly.');
    } else {
      console.log('⚠️  Some tests failed. Check the details above.');
    }
    
    console.log('\n=== Test Details ===');
    this.testResults.forEach(result => {
      console.log(`${result.testName}: ${result.status} - ${result.message}`);
    });
  }
}

// Run tests when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  // Wait a bit for other scripts to initialize
  setTimeout(() => {
    window.realTimeTest = new RealTimeTest();
  }, 2000);
});

// Make RealTimeTest globally available
if (typeof window !== 'undefined') {
  window.RealTimeTest = RealTimeTest;
}