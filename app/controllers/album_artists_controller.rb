class AlbumArtistsController < ApplicationController
  def index
    artists = AlbumArtist.all
    render json: artists
  end

  def show
    artist = AlbumArtist.find(params[:id])
    render json: artist
  end
end
