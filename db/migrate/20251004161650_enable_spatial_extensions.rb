class EnableSpatialExtensions < ActiveRecord::Migration[8.0]
  def up
    # Enable spatial extensions for GIS functionality
    # Note: For SQLite, we'll use simple lat/lng columns with spatial logic in models
    # For PostgreSQL/PostGIS in production, this would enable the PostGIS extension
    
    unless Rails.env.production?
      # Development/test: Add spatial indexing capability note
      # We'll simulate spatial functionality with lat/lng calculations
      execute "-- Spatial extensions enabled for development (using lat/lng calculations)"
    else
      # Production: Enable PostGIS if using PostgreSQL
      enable_extension 'postgis' if connection.extension_enabled?('postgis')
    end
  end
  
  def down
    # For development, this is just a comment so nothing to rollback
    unless Rails.env.production?
      execute "-- Spatial extensions disabled for development"
    else
      disable_extension 'postgis' if connection.extension_enabled?('postgis')
    end
  end
endialExtensions < ActiveRecord::Migration[8.0]
  def change
    # Enable spatial extensions for GIS functionality
    # Note: For SQLite, we'll use simple lat/lng columns with spatial logic in models
    # For PostgreSQL/PostGIS in production, this would enable the PostGIS extension
    
    unless Rails.env.production?
      # Development/test: Add spatial indexing capability note
      # We'll simulate spatial functionality with lat/lng columns and geometric calculations
      execute "-- Spatial extensions enabled for development (using lat/lng calculations)"
    else
      # Production: Enable PostGIS if using PostgreSQL
      enable_extension 'postgis' if connection.extension_enabled?('postgis')
    end
  end
end
