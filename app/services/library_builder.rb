# app/services/library_builder.rb
require "ostruct"

class LibraryBuilder
  def self.fetch_and_sort_songs(query: nil, sort: nil)
    library_path = Rails.root.join("storage", "library")
    return [] unless Dir.exist?(library_path)

    # 1. Get IDs of files physically on your drive
    local_ids = Dir.glob(library_path.join("*")).map { |path| File.basename(path, ".*") }

    # 2. Build the list from your LOCAL database (the work Dbupdater did)
    recognized_songs = local_ids.filter_map do |song_id|
      # Search your local MySQL tables
      local_song = SongInfo.find_by(songID: song_id)
      next nil unless local_song

      # Ensure these associations are actually loaded
      artist_list = local_song.artist_infos || []
      album_data = local_song.album_release&.album_info

      UiSong.build_from_api(
        local_song.attributes, # Pass the song attributes as a hash
        song_id,
        artist_list,
        album_data
      )
    end

    apply_search_and_sort!(recognized_songs, query, sort)
    recognized_songs
  end

  def self.fetch_unrecognized_files
    unrecognized_path = Rails.root.join("storage", "unrecognized")
    return [] unless Dir.exist?(unrecognized_path)

    Dir.glob(unrecognized_path.join("*")).map do |file|
      filename = File.basename(file, ".*")

      UiSong.build_from_api(
        { "songName" => filename, "songID" => filename },
        filename,
        [{ "artistName" => "Unknown Artist" }],
        { "albumName" => "Unknown Album" }
      )
    end
  end

  private

  def self.apply_search_and_sort!(songs, query, sort)
    if query.present?
      search_term = query.downcase
      songs.select! do |song|
        song.songName.to_s.downcase.include?(search_term) ||
          song.artist_infos.any? { |a| a.artistName.to_s.downcase.include?(search_term) } ||
          song.album_release.album_info.albumName.to_s.downcase.include?(search_term)
      end
    end

    case sort
    when "title"
      songs.sort_by! { |s| s.songName.to_s.downcase }
    when "artist"
      songs.sort_by! { |s| s.artist_infos.first&.artistName.to_s.downcase || "" }
    when "album"
      songs.sort_by! { |s| s.album_release.album_info.albumName.to_s.downcase }
    else
      songs.sort_by! { |s| s.songName.to_s.downcase }
    end
  end
end