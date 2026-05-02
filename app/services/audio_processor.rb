class AudioProcessor
  def self.call(file_path)
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    if new_hash.nil? || new_hash.length != 32
      puts "Invalid Hash generated. Skipping entry."
      return
    end

    clean_filename = File.basename(file_path, ".*")
    song_name_for_file = clean_filename
    is_recognized = false

    match_data = AcoustidClient.identify_audio(file_path)
    mbid = match_data.is_a?(Hash) ? match_data[:songID] : match_data
    release_id = match_data.is_a?(Hash) ? match_data[:releaseID] : nil

    if mbid.present? && release_id.nil?
      puts "Release ID missing. Automatically searching MusicBrainz for a linked album..."
      release_id = MusicbrainzHelper.find_release_by_recording_id(mbid)
    end

    song_id_for_ui = mbid.present? ? mbid.to_s.strip : "unrecognized_#{new_hash}"

    if mbid.present? && release_id.present?
      hash_str = new_hash.to_s.strip

      # Check the remote API first
      if GatekeeperClient.remote_hash_exists?(hash_str)
        puts "Known File: Hash already exists on the remote server."
      else
        puts "New File: Hash not found remotely. Triggering hydration..."
        GatekeeperClient.create_entry(
          raw_hash: hash_str,
          song_id: mbid.to_s.strip,
          release_id: release_id.to_s.strip
        )
      end

      album_placeholder_id = "placeholder_#{release_id}"

      AlbumInfo.find_or_create_by!(albumID: album_placeholder_id) do |a|
        a.albumName = "Identifying..."
      end

      AlbumRelease.find_or_create_by!(releaseID: release_id.to_s.strip) do |r|
        r.albumID = album_placeholder_id
      end

      # 2. Create the hollow Song record with the required releaseID
      SongInfo.find_or_create_by!(songID: mbid.to_s.strip) do |s|
        s.songName = "Identifying..."
        s.releaseID = release_id.to_s.strip
      end

      # 3. Finally, save the Fingerprint
      HashMatch.find_or_create_by!(raw_hash: hash_str, songID: mbid.to_s.strip)

      local_song = SongInfo.find_by(songID: mbid.to_s.strip)

      if local_song.present?
        api_name = local_song.songName

        if api_name.present? && api_name != clean_filename
          puts "Metadata retrieved: #{api_name}"
          song_name_for_file = api_name
        else
          puts "No new name in DB. Sticking with: #{clean_filename}"
        end
        is_recognized = true
      else
        puts "Delegating metadata to remote API for: #{clean_filename}"
        is_recognized = true
      end
    else
      if mbid.present?
        puts "Still missing Release ID for #{clean_filename}."
      else
        puts "No AcoustID match found for #{clean_filename}."
      end
    end

    # 3. FILE SYSTEM MOVEMENT
    # Delegates moving the physical .mp3/.flac to the dedicated File Manager
    stable_filename = is_recognized ? mbid.to_s.strip : song_name_for_file

    LibraryFileManager.move_file(
      file_path: file_path,
      is_recognized: is_recognized,
      stable_filename: stable_filename
    )

    # 4. UI BROADCAST
    # Delegates patching the UI and pushing the Turbo Stream to the Broadcaster
    puts "Broadcasted #{song_name_for_file} to the Library UI."
    LibraryBroadcaster.broadcast(
      song_id: song_id_for_ui,
      song_name: song_name_for_file,
      is_recognized: is_recognized
    )

    puts "--- Finished processing: #{song_name_for_file} ---"
  end
end