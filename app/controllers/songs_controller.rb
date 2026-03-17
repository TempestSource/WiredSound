class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:link, :update, :destroy]
  def index
    @songs = SongInfo.all
  end

  def show
  end

  def new
    @song = SongInfo.new(songName: "unlinked")
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
    @song = SongInfo.find(params[:id])
  end
  def song_params
    params.expect(song_info: [:songName])
  end
end
