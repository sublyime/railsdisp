Rails.application.routes.draw do
  # Main application routes
  root "home#index"
  get "dashboard", to: "home#dashboard"
  
  # RESTful resource routes for chemical dispersion modeling
  resources :chemicals
  resources :locations
  resources :weather_data
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
  
  # API routes for AJAX/WebSocket functionality
  namespace :api do
    namespace :v1 do
      resources :dispersion_events, only: [:show, :create, :update] do
        member do
          get :live_calculations
          get :plume_data
        end
      end
      resources :weather_data, only: [:index, :create, :update]
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
