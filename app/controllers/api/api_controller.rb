module Api
  class ApiController < ActionController::API
    include Authenticatable
    def render_error(message, status)
      render json: { error: message }, status: status
    end
  end
end
