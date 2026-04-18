module Api
  class SongsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]

    def index
      songs = SongInfo.all
      render json: songs
    end

    def show
      song = SongInfo.find(params[:id])
      artists = SongArtist.where(songID: song[:songID])
      render json: {
        song: song,
        artists: artists
      }
    rescue ActiveRecord::RecordNotFound
      render_error("Song not found", 404)
    end

  end
end