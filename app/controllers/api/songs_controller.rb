module Api
  class SongsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]
    before_action :admin_page, only: [:destroy, :update ]

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

    def destroy
      song = SongInfo.find(params[:id])
      artists = SongArtist.where(songID: song[:songID])
      song.destroy
      artists.each do |a|
        a.destroy
      end
    end

    def update
      song = SongInfo.find(params[:id])
      if song.update(song_params)
        render json: song, status: :ok
      else
        render_error(song.errors, :unprocessable_entity)
      end
    rescue ActiveRecord::RecordNotFound
      render_error("Song not found", 404)
    end

    private

    def song_params
      params.permit(:songName, :trackNumber, :releaseID)
    end

  end
end
