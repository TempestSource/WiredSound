# app/services/song_detail_builder.rb
class SongDetailBuilder
  def self.call(song_id)
    api_response = GatekeeperClient.fetch_single_song(song_id)

    if api_response && api_response["song"]
      build_from_remote(api_response, song_id)
    else
      build_fallback(song_id)
    end
  end

  private

  def self.build_from_remote(api_response, song_id)
    song_data = api_response["song"]
    target_release_id = song_data["releaseID"]

    artist_list = fetch_artists(api_response["artists"])
    album_data = fetch_album(target_release_id)

    UiSong.build_from_api(song_data, song_id, artist_list, album_data)
  end

  def self.fetch_artists(artists_data)
    artist_id = artists_data&.first&.dig("artistID")
    return [] unless artist_id

    artist_data_full = GatekeeperClient.fetch_single_artist(artist_id)
    actual_artist = artist_data_full&.dig("artist") || artist_data_full
    [actual_artist].compact
  end

  def self.fetch_album(target_release_id)
    return nil unless target_release_id

    raw_albums = GatekeeperClient.fetch_remote_albums || []
    all_albums = raw_albums.is_a?(Hash) ? (raw_albums.values.first || []) : Array(raw_albums)

    # Note: This is still an N+1 API bottleneck, but now it's isolated!
    all_albums.each do |stub|
      album_id = stub["albumID"] || stub.dig("album", "albumID")
      next unless album_id

      full_album_response = GatekeeperClient.fetch_single_album(album_id)
      next unless full_album_response

      releases_list = full_album_response["releases"] || []

      if releases_list.any? { |r| r["releaseID"].to_s == target_release_id.to_s }
        album_data = full_album_response["album"] || full_album_response
        ensure_cover_art!(album_data, target_release_id)

        return album_data # Breaks the loop and returns the data immediately
      end
    end

    nil
  end

  def self.ensure_cover_art!(album_data, target_release_id)
    if album_data["coverPath"].blank?
      puts "API coverPath is null! Fetching from CoverArtArchive..."
      local_cover_path = MetadataHelper.download_cover_art(target_release_id)
      album_data["coverPath"] = local_cover_path if local_cover_path
    end
  end

  def self.build_fallback(song_id)
    SongInfo.find_by(songID: song_id) ||
      UiSong.build_from_api({ "songName" => "Unrecognized Track", "songID" => song_id }, song_id)
  end
end