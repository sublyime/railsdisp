# Initializer for weather service configuration
# Sets up API keys and service configurations

Rails.application.configure do
  # Weather service configuration
  config.weather_services = ActiveSupport::OrderedOptions.new
  
  # OpenWeatherMap configuration
  config.weather_services.openweathermap = ActiveSupport::OrderedOptions.new
  config.weather_services.openweathermap.api_key = ENV['OPENWEATHERMAP_API_KEY']
  config.weather_services.openweathermap.rate_limit = 1000 # calls per day for free tier
  config.weather_services.openweathermap.timeout = 10.seconds
  
  # National Weather Service configuration
  config.weather_services.nws = ActiveSupport::OrderedOptions.new
  config.weather_services.nws.enabled = true
  config.weather_services.nws.timeout = 15.seconds
  config.weather_services.nws.user_agent = 'ChemicalDispersionApp/1.0 (contact@example.com)'
  
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