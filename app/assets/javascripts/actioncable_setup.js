// ActionCable Setup for Real-time Communication
// Initializes WebSocket connections and provides fallback mechanisms

class ActionCableManager {
  constructor() {
    this.cable = null;
    this.subscriptions = new Map();
    this.connectionRetries = 0;
    this.maxRetries = 5;
    this.retryDelay = 2000;
    
    // Initialize when document is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.initialize());
    } else {
      this.initialize();
    }
  }

  initialize() {
    try {
      // Check if ActionCable is available globally (loaded via CDN or asset pipeline)
      if (typeof ActionCable !== 'undefined') {
        this.cable = ActionCable.createConsumer();
        this.setupConnectionMonitoring();
        console.log('ActionCable initialized successfully');
      } else {
        console.warn('ActionCable not found, using fallback mode');
        this.enablePollingFallback();
      }
    } catch (error) {
      console.error('Failed to initialize ActionCable:', error);
      this.handleConnectionFailure();
    }
  }

  setupConnectionMonitoring() {
    if (!this.cable) return;

    // Check if connection and monitor exist
    if (this.cable.connection && this.cable.connection.monitor) {
      // Use connection state callbacks instead of addEventListener
      const originalConnect = this.cable.connection.connect;
      const originalDisconnect = this.cable.connection.disconnect;
      
      // Override connect method to track connection
      this.cable.connection.connect = () => {
        console.log('ActionCable connected');
        this.connectionRetries = 0;
        if (originalConnect) originalConnect.call(this.cable.connection);
      };
      
      // Override disconnect method to track disconnection
      this.cable.connection.disconnect = () => {
        console.log('ActionCable disconnected');
        this.handleConnectionFailure();
        if (originalDisconnect) originalDisconnect.call(this.cable.connection);
      };
      
      console.log('ActionCable connection monitoring set up');
    } else {
      console.log('ActionCable connection monitoring not available');
    }
  }

  subscribe(channelName, params = {}, callbacks = {}) {
    if (!this.cable) {
      console.warn('ActionCable not available, using fallback for', channelName);
      return this.createFallbackSubscription(channelName, callbacks);
    }

    try {
      const subscription = this.cable.subscriptions.create(
        { channel: channelName, ...params },
        {
          connected: () => {
            console.log(`Connected to ${channelName}`);
            if (callbacks.connected) callbacks.connected();
          },
          
          disconnected: () => {
            console.log(`Disconnected from ${channelName}`);
            if (callbacks.disconnected) callbacks.disconnected();
          },
          
          received: (data) => {
            if (callbacks.received) callbacks.received(data);
          }
        }
      );

      this.subscriptions.set(channelName, subscription);
      return subscription;
    } catch (error) {
      console.error(`Failed to subscribe to ${channelName}:`, error);
      return this.createFallbackSubscription(channelName, callbacks);
    }
  }

  createFallbackSubscription(channelName, callbacks) {
    console.log(`Creating fallback subscription for ${channelName}`);
    
    // Start polling for this channel
    const pollInterval = setInterval(() => {
      // Trigger polling event that other components can listen to
      document.dispatchEvent(new CustomEvent('actioncable-poll', {
        detail: { channel: channelName }
      }));
    }, 5000);
    
    return {
      unsubscribe: () => {
        clearInterval(pollInterval);
        console.log(`Unsubscribed from fallback ${channelName}`);
      }
    };
  }

  handleConnectionFailure() {
    if (this.connectionRetries < this.maxRetries) {
      this.connectionRetries++;
      console.log(`Retrying ActionCable connection (${this.connectionRetries}/${this.maxRetries})`);
      
      setTimeout(() => {
        this.initialize();
      }, this.retryDelay * this.connectionRetries);
    } else {
      console.error('Max ActionCable connection retries reached, using polling');
      this.enablePollingFallback();
    }
  }

  enablePollingFallback() {
    console.log('Enabling polling fallback for real-time updates');
    
    setInterval(() => {
      document.dispatchEvent(new CustomEvent('actioncable-fallback-poll'));
    }, 10000); // Poll every 10 seconds as fallback
  }

  // Method to check if ActionCable is connected
  isConnected() {
    if (!this.cable || !this.cable.connection) {
      return false;
    }
    
    // Check connection state
    const connection = this.cable.connection;
    return connection.isOpen && connection.isOpen() || 
           connection.state === 'open' || 
           connection.connectionMonitor?.isRunning();
  }
  
  // Get connection status details
  getConnectionStatus() {
    if (!this.cable || !this.cable.connection) {
      return { connected: false, state: 'no_cable' };
    }
    
    const connection = this.cable.connection;
    return {
      connected: this.isConnected(),
      state: connection.state || 'unknown',
      monitor_running: connection.connectionMonitor?.isRunning() || false
    };
  }
}

// Create global instance
window.ActionCableManager = new ActionCableManager();

// Make it available globally for other modules
if (typeof window !== 'undefined') {
  window.ActionCableManager = new ActionCableManager();
}