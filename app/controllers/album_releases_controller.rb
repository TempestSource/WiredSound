class AlbumReleasesController < ApplicationController
  def index
    releases = AlbumInfo.all
    render json: releases
  end

  def show
    releases = AlbumRelease.find(params[:id])
    render json: releases
  end
end
