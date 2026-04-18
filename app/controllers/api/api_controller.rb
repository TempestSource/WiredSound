module Api
  class ApiController < ActionController::API
    include Authenticatable
  end
end
