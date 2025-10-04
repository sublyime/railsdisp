class ReceptorsController < ApplicationController
  before_action :set_dispersion_event
  before_action :set_receptor, only: [:show, :edit, :update, :destroy]

  def index
    @receptors = @dispersion_event.receptors.order(:name)
  end

  def show
    @calculations = @receptor.dispersion_calculations.includes(:weather_datum).order(created_at: :desc).limit(20)
  end

  def new
    @receptor = @dispersion_event.receptors.build
  end

  def create
    @receptor = @dispersion_event.receptors.build(receptor_params)
    
    if @receptor.save
      redirect_to [@dispersion_event, @receptor], notice: 'Receptor was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @receptor.update(receptor_params)
      redirect_to [@dispersion_event, @receptor], notice: 'Receptor was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @receptor.destroy
    redirect_to dispersion_event_receptors_url(@dispersion_event), notice: 'Receptor was successfully deleted.'
  end

  private

  def set_dispersion_event
    @dispersion_event = DispersionEvent.find(params[:dispersion_event_id])
  end

  def set_receptor
    @receptor = @dispersion_event.receptors.find(params[:id])
  end

  def receptor_params
    params.require(:receptor).permit(:name, :latitude, :longitude, :height, :description)
  end
end
