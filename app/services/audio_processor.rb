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

    if mbid.present?
      puts "Recording identified. Finding preferred release..."
      release_id = MusicbrainzHelper.find_release_by_recording_id(mbid)
    end

    song_id_for_ui = mbid.present? ? mbid.to_s.strip : "unrecognized_#{new_hash}"

    if mbid.present? && release_id.present?
      hash_str = new_hash.to_s.strip

      # 1. Remote Sync
      if GatekeeperClient.remote_hash_exists?(hash_str)
        puts "Known File: Hash already exists on the remote server."
      else
        puts "New File: Hash not found remotely. Triggering hydration..."
        GatekeeperClient.create_entry(raw_hash: hash_str, song_id: mbid.to_s, release_id: release_id.to_s)
      end

      # 2. Local Hydration (The real work)
      puts "Triggering local metadata and cover download..."
      Dbupdater.db_add(hash_str, mbid.to_s.strip, release_id.to_s.strip)

      # 3. GET THE REAL DATA FOR THE BROADCASTER
      local_song = SongInfo.find_by(songID: mbid.to_s.strip)


      is_recognized = local_song.present?
      song_name_for_file = local_song&.songName || clean_filename
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