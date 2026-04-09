class AlbumInfosController < ApplicationController
  def index
    album = AlbumInfo.all
    render json: album
  end

  def show
    album = AlbumInfo.find(params[:id])
    render json: album
  end
end
