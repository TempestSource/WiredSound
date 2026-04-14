class ArtistInfosController < ApplicationController
  def index
    artists = ArtistInfo.all
    render json: artists
  end

  def show
    album = ArtistInfo.find(params[:id])
    render json: album
  end
end
