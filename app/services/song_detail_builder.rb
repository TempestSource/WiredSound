# app/services/song_detail_builder.rb
class SongDetailBuilder
  def self.call(song_id)
    api_response = GatekeeperClient.fetch_single_song(song_id)

    if api_response && api_response["song"]
      # If the API has data, sync it and return the result
      build_from_remote(api_response, song_id)
    else
      puts "Song not found on API (404). Aborting sync."
      nil
    end
  end

  private

  def self.build_from_remote(api_response, song_id)
    song_data = api_response["song"]
    target_release_id = song_data["releaseID"]

    artist_list = fetch_artists(api_response["artists"])
    album_data = fetch_album(target_release_id)

    # --- NEW: SYNC TO LOCAL DATABASE ---
    # This ensures AudioProcessor can find the record later
    sync_to_local_db(song_data, song_id, artist_list, album_data)

    # Return the UI object as usual
    UiSong.build_from_api(song_data, song_id, artist_list, album_data)
  end

  private

  def self.sync_to_local_db(song_data, song_id, artist_list, album_data)
    # 1. Save Artists
    artist_list.each do |a|
      ArtistInfo.find_or_create_by!(artistID: a["artistID"]) do |local|
        local.artistName = a["artistName"]
        local.artistType = a["artistType"]
      end
    end

    # 2. Save Album
    if album_data
      AlbumInfo.find_or_create_by!(albumID: album_data["albumID"]) do |local|
        local.albumName = album_data["albumName"]
        local.albumType = album_data["albumType"]
        local.releaseDate = album_data["releaseDate"]
        local.coverPath = album_data["coverPath"]
      end

      # Link the Release
      AlbumRelease.find_or_create_by!(releaseID: song_data["releaseID"], albumID: album_data["albumID"])
    end

    # 3. Save Song
    SongInfo.find_or_create_by!(songID: song_id) do |local|
      local.songName = song_data["songName"]
      local.releaseID = song_data["releaseID"]
      local.trackNumber = song_data["trackNumber"] || 0
    end
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
      puts "API coverPath is null. Attempting remote Gatekeeper fetch for #{target_release_id}..."

      remote_success = GatekeeperClient.download_release_cover(target_release_id)

      if remote_success
        album_data["coverPath"] = "/covers/#{target_release_id}.jpg"
        puts "Successfully downloaded cover from remote Gatekeeper."
        return # Exit early since we have the cover now
      end

      puts "Gatekeeper cover not found. Falling back to CoverArtArchive..."
      Metadata.cover(target_release_id)

      local_file = Rails.root.join('public', 'covers', "#{target_release_id}.jpg")
      if File.exist?(local_file)
        album_data["coverPath"] = "/covers/#{target_release_id}.jpg"
      end
    end
  end
end