require "ostruct"

class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:update]
  def index
    # Fetch and sort recognized songs using the service
    @recognized_songs = LibraryBuilder.fetch_and_sort_songs(
      query: params[:query],
      sort: params[:sort]
    )

    # Fetch physical files that aren't in the database yet
    @unrecognized_files = LibraryBuilder.fetch_unrecognized_files
  end

  def show
    @song = SongDetailBuilder.call(params[:id])
  end
  def play
    # Use the Service we built to find the path safely
    file_path = LibraryFileManager.find_file_path(params[:id])

    if file_path && File.exist?(file_path)
      send_file file_path, type: "audio/mpeg", disposition: "inline"
    else
      head :not_found
    end
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

  def create
    mbid = params[:mbid].strip
    old_filename = params[:filename]
    file_path = Rails.root.join("storage", "unrecognized", "#{old_filename}.mp3")

    unless File.exist?(file_path)
      flash[:alert] = "File not found."
      redirect_to root_path and return
    end


    @song = AudioProcessor.call(file_path.to_s)

    if @song
      flash[:notice] = "Successfully processed and linked '#{@song.songName}'!"
      redirect_to root_path
    else
      flash[:alert] = "Failed to process the song."
      redirect_to root_path
    end
  end
  def destroy
    file_id = params[:id]

    # 1. Ask the service to handle the hard drive
    files_deleted = LibraryFileManager.delete_file(file_id)

    # 2. Handle the database
    @song = SongInfo.find_by(songID: file_id)
    db_deleted = @song&.destroy

    if files_deleted || db_deleted
      flash[:notice] = "Successfully removed the song from your library and storage."
    else
      flash[:alert] = "Could not find the file or record to delete."
    end

    redirect_to songs_path
  end


  private

  def map_api_to_object(song_data, fallback_id = nil, artists = [], album = nil)
    actual_id = song_data["songID"] || fallback_id

    song = OpenStruct.new(
      songID: actual_id,
      songName: song_data["songName"],
      trackNumber: song_data["trackNumber"] || "N/A",
      artist_infos: artists.map { |a| OpenStruct.new(a) },
      album_release: OpenStruct.new(
        album_info: OpenStruct.new(album || { "albumName" => "Unknown Album" })
      )
    )

    def song.to_model; self; end
    def song.model_name; ActiveModel::Name.new(SongInfo); end
    def song.to_key; [songID]; end
    def song.persisted?; true; end
    def song.param_key; "song"; end
    def song.to_param; songID; end

    song
  end

  private

  def set_song
    @song = SongInfo.find_by(songID: params[:id]) || SongInfo.find_by(songName: params[:id])
    redirect_to songs_path, alert: "Song record not found." if @song.nil?
  end

  def song_params
    params.expect(song_info: [:songName])
  end
end