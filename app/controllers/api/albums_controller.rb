module Api
  class AlbumsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]

    def index
      albums = AlbumInfo.all
      render json: albums
    end

    def show
      album = AlbumInfo.find(params[:id])
      releases = AlbumRelease.where(albumID: album.id)
      artists = AlbumArtist.where(albumID: album.id)

      render json: {
        album: album,
        releases: releases,
        artists: artists
      }
    rescue ActiveRecord::RecordNotFound
      render_error("Album not found", 404)
    end
  end
end