Rails.application.routes.draw do
  # Main application routes
  root "home#index"
  get "dashboard", to: "home#dashboard"
  
  # Favicon route
  get '/favicon.ico', to: proc { [200, {}, ['']] }
  
  # GIS and Mapping Resources
  resources :map_layers do
    collection do
      get :geojson
      post :bulk_toggle_visibility
      post :reorder
    end
    
    member do
      get :bounds
      get :features
      post :toggle_visibility
    end
    
    # Nested resources for layer-specific features
    resources :buildings, except: [:new, :edit]
    resources :terrain_points, except: [:new, :edit]
    resources :gis_features, except: [:new, :edit]
  end
  
  # Standalone GIS resource routes (for cross-layer operations)
  resources :buildings do
    collection do
      get :search
      get :geojson
      get :in_bounds
    end
    
    member do
      get :geojson
    end
  end
  
  resources :terrain_points do
    collection do
      get :elevation_at
      post :interpolate_elevation
      post :import_data
      get :geojson
    end
    
    member do
      get :neighbors
    end
  end
  
  resources :gis_features do
    collection do
      get :search
      get :geojson
      get :by_type
    end
    
    member do
      get :geojson
      post :check_contains_point
    end
  end
  
  # RESTful resource routes for chemical dispersion modeling
  resources :chemicals
  resources :locations
  resources :weather_data, path: 'weather' do
    collection do
      post :update_all
      post :update_location
      post :for_dispersion
      get 'current/:latitude/:longitude', action: :current, as: :current
      get 'forecast/:latitude/:longitude', action: :forecast, as: :forecast
      get 'stations_near/:latitude/:longitude', action: :stations_near, as: :stations_near
      get 'atmospheric_stability/:latitude/:longitude', action: :atmospheric_stability, as: :atmospheric_stability
    end
  end
  resources :dispersion_events do
    # Nested routes for associated resources
    resources :receptors
    resources :dispersion_calculations
    
    # Custom routes for real-time functionality
    member do
      get :calculate
      post :start_monitoring
      delete :stop_monitoring
    end
  end
  
  # API routes for AJAX/WebSocket integration
  namespace :api do
    namespace :v1 do
      # GIS API endpoints
      resources :map_layers, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :geojson
        end
      end
      
      resources :buildings, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :geojson
          get 'in_bounds/:north/:south/:east/:west', action: :in_bounds
        end
      end
      
      resources :terrain_points, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :geojson
          get 'elevation/:latitude/:longitude', action: :elevation_at
          post :bulk_import
        end
      end
      
      resources :gis_features, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get :geojson
          get 'by_type/:feature_type', action: :by_type
        end
      end
      
      # Dispersion modeling API
      resources :dispersion_events, only: [:index, :show, :create, :update] do
        member do
          get :live_calculations
          get :plume_data
        end
      end
      
      resources :weather, only: [:index, :show] do
        collection do
          get :current
          get :at_location
        end
      end
    end
  end

  # Test routes for WebSocket functionality
  get 'test', to: 'test#websocket_test'
  get 'test/weather_broadcast', to: 'test#trigger_weather_broadcast'
  get 'test/dispersion_broadcast', to: 'test#trigger_dispersion_broadcast'
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
