module Api
  module V1
    module Auth
      class AuthController < ApiController
        skip_before_action :authenticate, only: [:login, :sign_up]

        # /api/v1/auth/login
        def login
          unless params[:username].present? && params[:password].present?
            return render_error("Requires username and password", :bad_request)
          end

          user = User.authenticate(params[:username], params[:password])

          unless user
            return render_error("Invalid username or password", :unauthorized)
          end

          tokens = JwtAuth.create_token_pair(user.username)

          render json: {
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            token_type: "Bearer",
            expires_in: ENV.fetch("JWT_ACCESS_TIMEOUT", 600).to_i,
            user: user_info(user)
          }, status: :ok

        end

        def sign_up
          unless params[:username].present? && params[:password].present?
            return render_error("Requires username and password", :bad_request)
          end

          if User.find_by(username: params[:username])
            return render_error("Username already taken", :not_found)
          end

          created = User.create!(sign_up_info)
          if created.valid?
            render json: "User created successfully", status: :created
          else
            return render_error("User not created", :bad_request)
          end
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
