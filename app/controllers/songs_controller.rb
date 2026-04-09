class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:show, :link, :update, :destroy]
  def index
    library_files = Dir.glob(Rails.root.join("storage", "library", "*.mp3")).map { |f| File.basename(f) }
    unrecognized_files = Dir.glob(Rails.root.join("storage", "unrecognized", "*.mp3")).map { |f| File.basename(f) }
    all_physical_files = library_files + unrecognized_files

    @songs = SongInfo.all.select do |song|
      all_physical_files.any? { |filename| filename.include?(song.songName) }
    end
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
    file_path = Rails.root.join("storage", "library", "#{@song.songName}.mp3")

    if File.exist?(file_path)
      File.delete(file_path)
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