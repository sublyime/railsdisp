# Initializer for weather service configuration
# Sets up API keys and service configurations

Rails.application.configure do
  # Weather service configuration
  config.weather_services = ActiveSupport::OrderedOptions.new
  
  # National Weather Service configuration (PRIMARY PROVIDER)
  # Uses api.weather.gov for all weather data - no API key required
  config.weather_services.nws = ActiveSupport::OrderedOptions.new
  config.weather_services.nws.enabled = true
  config.weather_services.nws.timeout = 15.seconds
  config.weather_services.nws.user_agent = 'ChemicalDispersionApp/1.0 (railsdisp@example.com)'
  config.weather_services.nws.base_url = 'https://api.weather.gov'
  
  # Disable OpenWeatherMap - using only government weather data sources
  config.weather_services.openweathermap = ActiveSupport::OrderedOptions.new
  config.weather_services.openweathermap.enabled = false
  config.weather_services.openweathermap.api_key = nil # Explicitly disable
  
  # Weather update configuration
  config.weather_updates = ActiveSupport::OrderedOptions.new
  config.weather_updates.interval = 30.seconds
  config.weather_updates.enabled = true
  config.weather_updates.max_retries = 3
  
  # Cache configuration for weather data
  config.cache_store = :memory_store, { size: 64.megabytes }
end

# Schedule periodic weather updates
if Rails.env.production? || Rails.env.development?
  Rails.application.config.after_initialize do
    if Rails.application.config.weather_updates.enabled
      # Schedule weather updates every 30 seconds in a background thread
      Thread.new do
        loop do
          begin
            WeatherUpdateJob.perform_later
          rescue => e
            Rails.logger.error "Failed to schedule weather update: #{e.message}"
          end
          
          sleep Rails.application.config.weather_updates.interval
        end
      end if defined?(WeatherUpdateJob)
    end
  end
end