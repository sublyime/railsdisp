class LocationsController < ApplicationController
  before_action :set_location, only: [:show, :edit, :update, :destroy]

  def index
    @locations = Location.all.order(:name)
    
    respond_to do |format|
      format.html
      format.json { render json: @locations }
    end
  end

  def show
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)
    
    if @location.save
      redirect_to @location, notice: 'Location was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to @location, notice: 'Location was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @location.destroy
    redirect_to locations_url, notice: 'Location was successfully deleted.'
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :latitude, :longitude, :elevation, 
                                   :terrain_type, :building_height, :description)
  end
end
