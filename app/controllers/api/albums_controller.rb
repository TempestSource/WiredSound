module Api
  class AlbumsController < ApiController
    skip_before_action :authenticate, only: [ :index, :show, :cover ]
    before_action :admin_page, only: [ :destroy, :update ]

    COVER_PATH = ENV.fetch('COVER_PATH', './covers')

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

    def cover
      album = AlbumRelease.find(params[:id])
      image_path = Rails.root.join(COVER_PATH, "#{album.id.to_s}.jpg")

      if File.exist?(image_path)
        send_file image_path, type: 'image/jpeg'
      else
        render_error("Cover image not found", 404)
      end

    rescue ActiveRecord::RecordNotFound
      render_error("Album release not found", 404)
    end

    private
    def album_params
      params.permit(:albumName, :albumType, :coverPath, :releaseDate)
    end
  end
end