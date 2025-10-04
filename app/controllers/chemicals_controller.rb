class ChemicalsController < ApplicationController
  before_action :set_chemical, only: [:show, :edit, :update, :destroy]

  def index
    @chemicals = Chemical.all.order(:name)
  end

  def show
  end

  def new
    @chemical = Chemical.new
  end

  def create
    @chemical = Chemical.new(chemical_params)
    
    if @chemical.save
      redirect_to @chemical, notice: 'Chemical was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @chemical.update(chemical_params)
      redirect_to @chemical, notice: 'Chemical was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @chemical.destroy
    redirect_to chemicals_url, notice: 'Chemical was successfully deleted.'
  end

  private

  def set_chemical
    @chemical = Chemical.find(params[:id])
  end

  def chemical_params
    params.require(:chemical).permit(:name, :cas_number, :molecular_weight, :boiling_point, 
                                   :vapor_pressure, :solubility, :state, :density, 
                                   :flash_point, :auto_ignition_temp, :lel, :uel, 
                                   :tlv_twa, :tlv_stel, :idlh)
  end
end
