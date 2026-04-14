class HashMatchesController < ApplicationController
  def index
    song = HashMatch.all
    render json: song
  end

  def show
    song = HashMatch.find(params[:id])
    render json: song
  end
end
