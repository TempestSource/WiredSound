module Api
  module V1
    module Auth
      class AuthController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :authenticate, only: [:login, :sign_up]

        # /api/v1/auth/login
        def login
          unless params[:username].present? && params[:password].present?
            return render_error('Requires username and password', :bad_request)
          end

          user = User.authenticate(params[:username], params[:password])

          unless user
            return render_error('Invalid username or password', :unauthorized)
          end

          tokens = JwtAuth.create_token_pair(user.username)

          render json: {
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            token_type: 'Bearer',
            expires_in: ENV.fetch('JWT_ACCESS_TIMEOUT', 600).to_i,
            user: user_info(user)
          }, status: :ok

        end

        def sign_up
          unless params[:username].present? && params[:password].present?
            return render_error('Requires username and password', :bad_request)
          end

          User.create!(sign_up_info)
        end

        # TODO: logout
        # TODO: refresh
        private

        def user_info(user)
          {
            username: user.username
          }
        end

        def sign_up_info
          params.permit(:username, :password)
        end

        def render_error(message, status)
          render json: { error: message }, status: status
        end
      end
    end
  end
end