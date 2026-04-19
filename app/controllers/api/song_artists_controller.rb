module Api
  class SongArtistsController < ApplicationController
    def index
      artists = SongArtist.all
      render json: artists
    end

    def show
      artists = SongArtist.find(params[:id])
      render json: artists
    end
  end
end