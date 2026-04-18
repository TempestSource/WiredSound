module Api
  class ArtistsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]
    def index
      artists = ArtistInfo.all
      render json: artists
    end

    def show
      artist = ArtistInfo.find(params[:id])
      render json: artist
    rescue ActiveRecord::RecordNotFound
      render_error("Artist not found", 404)
    end
  end
end