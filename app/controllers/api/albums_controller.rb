module Api
  class AlbumsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show ]
    before_action :admin_page, only: [ :destroy, :update ]

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

    def destroy
      album = AlbumInfo.find(params[:id])
      artists = AlbumArtist.where(albumID: album.id)
      releases = AlbumRelease.where(albumID: album.id)

      album.destroy
      artists.destroy_all
      releases.destroy_all
    rescue ActiveRecord::RecordNotFound
      render_error("Album not found", 404)
    end

    def update
      album = AlbumInfo.find(params[:id])
      if album.update(album_params)
        render json: album
      else
        render_error(album.errors, :unprocessable_entity)
      end
    rescue ActiveRecord::RecordNotFound
      render_error("Album not found", 404)
    end

    private
    def album_params
      params.permit(:albumName, :albumType, :coverPath, :releaseDate)
    end
  end
end