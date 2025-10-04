class Api::V1::LocationsController < Api::V1::BaseController
  def index
    @locations = Location.all.order(:name)
    
    render_success({
      locations: @locations.map { |location| location_data(location) },
      count: @locations.count
    })
  end

  private

  def location_data(location)
    {
      id: location.id,
      name: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      elevation: location.elevation,
      terrain_type: location.terrain_type,
      building_height: location.building_height,
      description: location.description
    }
  end
end