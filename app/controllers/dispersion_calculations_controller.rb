class DispersionCalculationsController < ApplicationController
  before_action :set_dispersion_event
  before_action :set_dispersion_calculation, only: [:show, :edit, :update, :destroy]

  def index
    @dispersion_calculations = @dispersion_event.dispersion_calculations
                                               .includes(:weather_datum)
                                               .order(created_at: :desc)
                                               .page(params[:page])
  end

  def show
  end

  def new
    @dispersion_calculation = @dispersion_event.dispersion_calculations.build
    @weather_data = WeatherDatum.order(timestamp: :desc).limit(10)
  end

  def create
    @dispersion_calculation = @dispersion_event.dispersion_calculations.build(dispersion_calculation_params)
    
    if @dispersion_calculation.save
      # Trigger the actual calculation
      @dispersion_calculation.calculate_concentrations
      redirect_to [@dispersion_event, @dispersion_calculation], notice: 'Calculation was successfully created.'
    else
      @weather_data = WeatherDatum.order(timestamp: :desc).limit(10)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @weather_data = WeatherDatum.order(timestamp: :desc).limit(10)
  end

  def update
    if @dispersion_calculation.update(dispersion_calculation_params)
      # Recalculate with new parameters
      @dispersion_calculation.calculate_concentrations
      redirect_to [@dispersion_event, @dispersion_calculation], notice: 'Calculation was successfully updated.'
    else
      @weather_data = WeatherDatum.order(timestamp: :desc).limit(10)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @dispersion_calculation.destroy
    redirect_to dispersion_event_dispersion_calculations_url(@dispersion_event), 
                notice: 'Calculation was successfully deleted.'
  end

  private

  def set_dispersion_event
    @dispersion_event = DispersionEvent.find(params[:dispersion_event_id])
  end

  def set_dispersion_calculation
    @dispersion_calculation = @dispersion_event.dispersion_calculations.find(params[:id])
  end

  def dispersion_calculation_params
    params.require(:dispersion_calculation).permit(:weather_datum_id, :receptor_latitude, 
                                                  :receptor_longitude, :receptor_height, 
                                                  :calculation_type, :effective_height)
  end
end
