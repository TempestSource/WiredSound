module Api
  class HashesController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]
    before_action :admin_page, only: [ :destroy ]
    def index
      hashes = HashMatch.all
      render json: hashes
    end

    def show
      hash = HashMatch.find(params[:id])
      render json: hash
    end

    def create
      match = HashMatch.create!(hash_params)
      if match.save
        render json: match, status: :created
      else
        render_error(match.errors, :unprocessable_entity)
      end
    end

    def destroy
      hash = HashMatch.find(params[:id])
      hash.destroy
    rescue ActiveRecord::RecordNotFound
      render_error("Hash not found", 404)
    end

    def update
      hash = HashMatch.find(params[:id])
      if hash.update(hash_params)
        render json: hash, status: :ok
      else
        render_error(hash.errors, :unprocessable_entity)
      end
    rescue ActiveRecord::RecordNotFound
      render_error("Hash not found", 404)
    end

    private

    def render_error(message, status)
      render json: { error: message }, status: status
    end

    def update_params
      params.permit(:id, :songID)
    end
    def hash_params
      params.permit(:raw_hash, :songID)
    end

  end
end
