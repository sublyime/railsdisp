// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import { Application } from "@hotwired/stimulus"
import "@hotwired/turbo-rails"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Import our custom JavaScript modules - these will be loaded as separate files
import "actioncable_setup"
import "dispersion_map"
import "weather_manager"
import "realtime_dispersion"
import "realtime_test"
import "module_integration_test"

export { application }