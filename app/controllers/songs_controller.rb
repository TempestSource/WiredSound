class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:show, :link, :update, :destroy]
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
    file_path = @song.filePath

    if file_path.present? && File.exist?(file_path)
      File.delete(file_path)

      @song.update(filePath: nil)

      flash[:notice] = "The local audio file was deleted, but the database record was kept."
    else
      flash[:alert] = "Database record kept, but the physical file was not found on the server."
    end

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