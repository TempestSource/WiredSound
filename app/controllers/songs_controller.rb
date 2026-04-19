require "ostruct"

class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:update, :destroy]
  def index
    @recognized_songs = SongInfo.includes(:artist_infos, album_release: :album_info)

    if params[:query].present?
      search_query = "%#{params[:query]}%"
      @recognized_songs = @recognized_songs.left_joins(:artist_infos, album_release: :album_info)
                                           .where("song_info.songName LIKE ? OR
                                                   artist_info.artistName LIKE ? OR
                                                   album_info.albumName LIKE ?",
                                                  search_query, search_query, search_query).distinct
    end

    @recognized_songs = case params[:sort]
                        when "title"
                          @recognized_songs.order(:songName)
                        when "artist"
                          @recognized_songs.joins(:artist_infos).order('artist_info.artistName')
                        when "album"
                          @recognized_songs.joins(album_release: :album_info).order('album_info.albumName')
                        else
                          @recognized_songs.order(:songName)
                        end
    @recognized_songs = @recognized_songs.select do |song|
      file_path = Rails.root.join("storage", "library", "#{song.songName}.mp3")
      File.exist?(file_path)
    end
    unrecognized_path = Rails.root.join("storage", "unrecognized", "*.mp3")
    @unrecognized_files = Dir.glob(unrecognized_path).map do |file_path|
      filename = File.basename(file_path, ".mp3")
      OpenStruct.new(songName: filename, songID: filename, is_local: true)
    end
  end

  def show
    @song = SongInfo.find_by(songID: params[:id])

    if @song.nil?
      unrecognized_path = Rails.root.join("storage", "unrecognized", "#{params[:id]}.mp3")
      incoming_path = Rails.root.join("storage", "incoming_music", "#{params[:id]}.mp3")

      active_path = File.exist?(unrecognized_path) ? unrecognized_path : (File.exist?(incoming_path) ? incoming_path : nil)

      if active_path
        @song = OpenStruct.new(
          songName: params[:id],
          songID: params[:id],
          is_local: true,
          artist_infos: [],
          trackNumber: "N/A"
        )
      else
        redirect_to songs_path, alert: "Song file not found. It may have been moved or deleted."
      end
    end
  end
  def play
    song_record = SongInfo.find_by(songID: params[:id])

    base_path = if song_record
                  Rails.root.join("storage", "library", song_record.songName.to_s)
                else
                  Rails.root.join("storage", "unrecognized", params[:id].to_s)
                end

    file_path = Dir.glob("#{base_path}.*").first

    if file_path && File.exist?(file_path)
      size = File.size(file_path)

      response.headers['Accept-Ranges'] = 'bytes'
      response.headers['Content-Length'] = size.to_s

      send_file file_path,
                type: 'audio/mpeg',
                disposition: 'inline',
                stream: true,
                buffer_size: 4096
      content_type = Rack::Mime.mime_type(File.extname(file_path))
      send_file file_path, type: content_type, disposition: "inline"
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


    @song = AudioProcessor.call(file_path.to_s, {})

    if @song
      flash[:notice] = "Successfully processed and linked '#{@song.songName}'!"
      redirect_to root_path
    else
      flash[:alert] = "Failed to process the song."
      redirect_to root_path
    end
  end
  def destroy
    @song = SongInfo.find_by!(songID: params[:id])

    library_path = Rails.root.join("storage", "library", "#{@song.songName}.mp3")
    unrecognized_path = Rails.root.join("storage", "unrecognized", "#{@song.songName}.mp3")

    File.delete(library_path) if File.exist?(library_path)
    File.delete(unrecognized_path) if File.exist?(unrecognized_path)


    if @song.destroy
      flash[:notice] = "Successfully deleted '#{@song.songName}' from your library and storage."
    else
      flash[:alert] = "The file was removed, but there was an error updating the database."
    end

    redirect_to songs_path
  end

  private

  def set_song
    @song = SongInfo.find_by(songID: params[:id])
    redirect_to songs_path, alert: "Song record not found." if @song.nil?
  end

  def song_params
    params.expect(song_info: [:songName])
  end
end