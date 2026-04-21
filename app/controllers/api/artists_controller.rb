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
      artist = ArtistInfo.find(params[:id])
      albums = AlbumArtist.where(artistID: artist.id)
      songs = SongArtist.where(artistID: artist.id)
      artist.destroy
      albums.destroy_all
      songs.destroy_all
    rescue ActiveRecord::RecordNotFound
      render_error("Artist not found", 404)
    end

    def update
      artist = ArtistInfo.find(params[:id])
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