class SongsController < ApplicationController
  before_action :set_song, only: [:show, :link, :update, :destroy]
  def index
    @songs = Song.all
  end

  def show
  end

  def new
    @song = Song.new(name: "unlinked")
    @song.save
    redirect_to songs_path
  end

  def link
  end

  def update
    if @song.update(song_params)
      redirect_to @song
    else
      render :link, status: :unprocessable_entity
    end
  end

  def destroy
    @song.destroy
    redirect_to songs_path
  end

  private
  def set_song
    @song = Song.find(params[:id])
  end
  def song_params
    params.expect(song: [:name, :artist])
  end
end
