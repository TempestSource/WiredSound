module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
    attr_reader :current_user
  end

  private

  def extract_token(header)
    return nil unless header.present? && header.start_with?("Bearer")

    header.split(" ").last
  end

  def unauthorized(e = "Unauthorized")
    render json: { error: e }, status: :unauthorized
  end

  def authenticate
    header = request.headers["Authorization"]
    token = extract_token(header)

    unless token
      unauthorized("Missing token"); return
    end

    begin
      payload = JwtAuth.decode_token(token)

      @current_user = User.find_by(username: payload[:username])

      unless @current_user
        unauthorized("Invalid user"); return
      end

    rescue JWT::DecodeError => e
      unauthorized(e.message)

    end

  end

  def admin_page
    unless @current_user&.role == "admin"
      render json: { error: "User is not an administrator" }, status: :forbidden; return
    end
  end
end
