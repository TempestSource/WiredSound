require "ostruct"

class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:update]
  def index
    library_path = Rails.root.join("storage", "library")
    local_ids = Dir.glob(library_path.join("*")).map { |path| File.basename(path, ".*") }

    raw_songs = AudioProcessor.fetch_remote_songs || []
    api_songs = raw_songs.is_a?(Hash) ? (raw_songs.values.first || []) : Array(raw_songs)

    raw_albums = AudioProcessor.fetch_remote_albums || []
    all_albums = raw_albums.is_a?(Hash) ? (raw_albums.values.first || []) : Array(raw_albums)

    filtered_api_songs = api_songs.select do |api_song|
      local_ids.include?(api_song["songID"])
    end

    artist_cache = {}
    release_to_album_cache = {}

    @recognized_songs = filtered_api_songs.filter_map do |shallow_song|
      song_id = shallow_song["songID"]

      deep_song = AudioProcessor.fetch_single_song(song_id)
      next nil unless deep_song && deep_song["song"]

      song_data = deep_song["song"]
      target_release_id = song_data["releaseID"]

      artist_id = deep_song["artists"]&.first&.dig("artistID")
      artist_list = []
      if artist_id
        artist_cache[artist_id] ||= AudioProcessor.fetch_single_artist(artist_id)
        actual_artist = artist_cache[artist_id]&.dig("artist") || artist_cache[artist_id]
        artist_list = [actual_artist].compact
      end

      album_data = nil
      if target_release_id
        if release_to_album_cache.key?(target_release_id)
          album_data = release_to_album_cache[target_release_id]
        else
          all_albums.each do |stub|
            album_id = stub["albumID"] || stub.dig("album", "albumID")
            next unless album_id

            full_album_response = AudioProcessor.fetch_single_album(album_id)
            next unless full_album_response

            releases_list = full_album_response["releases"] || []
            match = releases_list.any? { |r| r["releaseID"].to_s == target_release_id.to_s }

            if match
              album_data = full_album_response["album"] || full_album_response

              if album_data["coverPath"].blank?
                local_cover = MetadataHelper.download_cover_art(target_release_id)
                album_data["coverPath"] = local_cover if local_cover
              end

              release_to_album_cache[target_release_id] = album_data
              break
            end
          end
        end
      end

      map_api_to_object(song_data, song_id, artist_list, album_data)
    end

    if params[:query].present?
      search_query = params[:query].downcase
      @recognized_songs.select! do |song|
        song.songName.to_s.downcase.include?(search_query) ||
          song.artist_infos.any? { |a| a.artistName.to_s.downcase.include?(search_query) } ||
          song.album_release.album_info.albumName.to_s.downcase.include?(search_query)
      end
    end

    case params[:sort]
    when "title"
      @recognized_songs.sort_by! { |s| s.songName.to_s.downcase }
    when "artist"
      @recognized_songs.sort_by! { |s| s.artist_infos.first&.artistName.to_s.downcase || "" }
    when "album"
      @recognized_songs.sort_by! { |s| s.album_release.album_info.albumName.to_s.downcase }
    else
      @recognized_songs.sort_by! { |s| s.songName.to_s.downcase }
    end

    unrecognized_path = Rails.root.join("storage", "unrecognized", "*.mp3")
    @unrecognized_files = Dir.glob(unrecognized_path).map do |file_path|
      filename = File.basename(file_path, ".mp3")
      OpenStruct.new(songName: filename, songID: filename, is_local: true)
    end
  end

  def show
    api_response = AudioProcessor.fetch_single_song(params[:id])

    if api_response && api_response["song"]
      song_data = api_response["song"]
      target_release_id = song_data["releaseID"]

      artist_id = api_response["artists"]&.first&.dig("artistID")
      artist_list = []
      if artist_id
        artist_data_full = AudioProcessor.fetch_single_artist(artist_id)
        actual_artist = artist_data_full&.dig("artist") || artist_data_full
        artist_list = [actual_artist].compact
      end

      album_data = nil
      if target_release_id
        raw_albums = AudioProcessor.fetch_remote_albums || []
        all_albums = raw_albums.is_a?(Hash) ? (raw_albums.values.first || []) : Array(raw_albums)

        all_albums.each do |stub|
          album_id = stub["albumID"] || stub.dig("album", "albumID")
          next unless album_id

          full_album_response = AudioProcessor.fetch_single_album(album_id)
          next unless full_album_response


          releases_list = full_album_response["releases"] || []

          match = releases_list.any? { |r| r["releaseID"].to_s == target_release_id.to_s }

          match = releases_list.any? { |r| r["releaseID"].to_s == target_release_id.to_s }

          if match
            puts "✅ DEBUG: Found matching ReleaseID in Album: #{album_id}"

            album_data = full_album_response["album"] || full_album_response

            if album_data["coverPath"].blank?
              puts "🖼️ API coverPath is null! Fetching from CoverArtArchive..."

              local_cover_path = MetadataHelper.download_cover_art(target_release_id)

              album_data["coverPath"] = local_cover_path if local_cover_path
            end

            break
          end
        end
      end

      @song = map_api_to_object(song_data, params[:id], artist_list, album_data)
    else
      @song = SongInfo.find_by(songID: params[:id]) ||
              OpenStruct.new(songName: "Unrecognized Track", songID: params[:id], artist_infos: [])
    end
  end
  def play
    library_base = Rails.root.join("storage", "library", params[:id].to_s)
    unrecognized_base = Rails.root.join("storage", "unrecognized", params[:id].to_s)

    file_path = Dir.glob("#{library_base}.*").first || Dir.glob("#{unrecognized_base}.*").first

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
    file_id = params[:id]

    library_pattern = Rails.root.join("storage", "library", "#{file_id}.*")
    unrecognized_pattern = Rails.root.join("storage", "unrecognized", "#{file_id}.*")

    files_to_delete = Dir.glob([library_pattern, unrecognized_pattern])
    files_deleted = false

    files_to_delete.each do |file|
      File.delete(file)
      files_deleted = true
      puts "Deleted physical file: #{file}"
    end

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