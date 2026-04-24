module Api
  class ArtistsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]
    before_action :admin_page, only: [ :destroy, :update ]
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

    def destroy
      artist = ArtistInfo.find_by!(artistID: params[:id])

      AlbumArtist.where(artistID: artist.artistID).destroy_all
      SongArtist.where(artistID: artist.artistID).destroy_all

      artist.destroy
      render json: { message: "Artist and associations removed" }, status: :ok
    rescue ActiveRecord::RecordNotFound
      render_error("Artist not found", 404)
    end

    def update
      # FIX: Use find_by! with artistID to support UUID strings in the URL
      artist = ArtistInfo.find_by!(artistID: params[:id])
      if artist.update(artist_params)
        render json: artist, status: :ok
      else
        render_error(artist.errors, :unprocessable_entity)
      end
    rescue ActiveRecord::RecordNotFound
      render_error("Artist not found", 404)
    end

    private

    def artist_params
      params.permit(:artistBegin, :artistCountry, :artistName, :artistType)
    end

  end
end