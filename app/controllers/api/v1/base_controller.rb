class Api::V1::BaseController < ApplicationController
  # Skip CSRF protection for API requests
  skip_before_action :verify_authenticity_token
  
  # Set JSON as default response format
  before_action :set_default_response_format
  
  private
  
  def set_default_response_format
    request.format = :json
  end
  
  def render_error(message, status = :unprocessable_entity)
    render json: { status: 'error', message: message }, status: status
  end
  
  def render_success(data, message = 'Success')
    render json: { status: 'success', message: message, data: data }, status: :ok
  end
end