class SongInfosController < ApplicationController
  def index
    song = SongInfo.all
    render json: song
  end

  def show
    song = SongInfo.find(params[:id])
    render json: song
  end
end
