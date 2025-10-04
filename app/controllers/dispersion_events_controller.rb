class DispersionEventsController < ApplicationController
  before_action :set_dispersion_event, only: [:show, :edit, :update, :destroy, :calculate, :start_monitoring, :stop_monitoring]

  def index
    @dispersion_events = DispersionEvent.includes(:chemical, :location).order(created_at: :desc)
  end

  def show
    @receptors = @dispersion_event.receptors.includes(:dispersion_calculations)
    @latest_calculations = @dispersion_event.dispersion_calculations.includes(:weather_datum).order(created_at: :desc).limit(10)
  end

  def new
    @dispersion_event = DispersionEvent.new
    @chemicals = Chemical.all.order(:name)
    @locations = Location.all.order(:name)
  end

  def create
    @dispersion_event = DispersionEvent.new(dispersion_event_params)
    
    if @dispersion_event.save
      # Automatically create default receptor grid around the source
      create_default_receptors
      redirect_to @dispersion_event, notice: 'Dispersion event was successfully created.'
    else
      @chemicals = Chemical.all.order(:name)
      @locations = Location.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @chemicals = Chemical.all.order(:name)
    @locations = Location.all.order(:name)
  end

  def update
    if @dispersion_event.update(dispersion_event_params)
      redirect_to @dispersion_event, notice: 'Dispersion event was successfully updated.'
    else
      @chemicals = Chemical.all.order(:name)
      @locations = Location.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @dispersion_event.destroy
    redirect_to dispersion_events_url, notice: 'Dispersion event was successfully deleted.'
  end

  def calculate
    # Trigger immediate calculation with current weather
    weather_data = WeatherDatum.order(timestamp: :desc).first
    
    if weather_data
      @dispersion_event.receptors.each do |receptor|
        DispersionCalculationJob.perform_later(@dispersion_event.id, receptor.id, weather_data.id)
      end
      
      redirect_to @dispersion_event, notice: 'Calculations started for all receptors.'
    else
      redirect_to @dispersion_event, alert: 'No weather data available for calculations.'
    end
  end

  def start_monitoring
    @dispersion_event.update(status: 'active')
    # Start background job for continuous calculations
    ContinuousDispersionJob.perform_later(@dispersion_event.id)
    redirect_to @dispersion_event, notice: 'Real-time monitoring started.'
  end

  def stop_monitoring
    @dispersion_event.update(status: 'completed')
    redirect_to @dispersion_event, notice: 'Real-time monitoring stopped.'
  end

  private

  private

  def set_dispersion_event
    @dispersion_event = DispersionEvent.find(params[:id])
  end

  def dispersion_event_params
    params.require(:dispersion_event).permit(
      :chemical_id, :location_id, :release_rate, :release_volume, 
      :release_mass, :release_duration, :release_type, :started_at, 
      :ended_at, :status, :notes
    )
  end

  def create_default_receptors
    # Create a grid of receptors around the source location
    source_lat = @dispersion_event.location.latitude
    source_lng = @dispersion_event.location.longitude
    
    # Create receptors at various distances and directions
    distances = [100, 500, 1000, 2000, 5000] # meters
    directions = [0, 45, 90, 135, 180, 225, 270, 315] # degrees
    
    distances.each do |distance|
      directions.each do |direction|
        # Calculate lat/lng offset based on distance and direction
        lat_offset = (distance * Math.cos(direction * Math::PI / 180)) / 111320.0
        lng_offset = (distance * Math.sin(direction * Math::PI / 180)) / (111320.0 * Math.cos(source_lat * Math::PI / 180))
        
        @dispersion_event.receptors.create!(
          name: "Receptor #{distance}m #{direction}°",
          latitude: source_lat + lat_offset,
          longitude: source_lng + lng_offset
        )
      end
    end
  end
end
