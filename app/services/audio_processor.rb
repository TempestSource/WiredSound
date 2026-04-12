require 'fileutils'
require 'securerandom'

class AudioProcessor
  def self.call(file_path, metadata = {})
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    match_record = ActiveRecord::Base.connection.execute(
      "SELECT songID FROM hash_match WHERE raw_hash = '#{new_hash}' LIMIT 1"
    ).first

    if match_record
      matched_song = SongInfo.find_by(songID: match_record.first)

      if matched_song
        library_path = Rails.root.join('storage', 'library', "#{matched_song.songName}.mp3")
        unrecognized_path = Rails.root.join('storage', 'unrecognized', "#{matched_song.songName}.mp3")

        if File.exist?(library_path) || File.exist?(unrecognized_path)
          puts "Duplicate: '#{matched_song.songName}' is already in the database and on disk."
          FileUtils.rm(file_path) if File.exist?(file_path)
          puts "Deleted duplicate file from incoming folder."
        else
          puts "Record found for '#{matched_song.songName}', but the physical file is missing. Restoring file..."

          target_dir = Rails.root.join('storage', 'library')
          FileUtils.mkdir_p(target_dir)
          new_path = target_dir.join("#{matched_song.songName}.mp3")

          FileUtils.mv(file_path, new_path)
          puts "Successfully restored physical file to: #{new_path}"
        end

        return matched_song
      else
        puts "Warning: Ghost hash detected. Deleting corrupted hash record and reprocessing..."
        ActiveRecord::Base.connection.execute(
          "DELETE FROM hash_match WHERE raw_hash = '#{new_hash}'"
        )
      end
    end

    puts "New file detected! Saving to database..."

    clean_filename = File.basename(file_path, ".*")
    is_recognized = !metadata.empty?

    if metadata.empty?
      puts "Step 1: High-Fidelity Lookup via AcoustID..."
      mbid = AcoustidClient.identify_audio(file_path)

      if mbid.blank?
        puts "Step 2: Fallback to Filename Search..."
        mbid = MetadataHelper.search_by_filename(clean_filename)
      end

      if mbid.present?
        puts "Success! MBID found: #{mbid}. Fetching official metadata..."

        begin
          mb = Metadata.new
          song_data = mb.process_song(mbid)

          sleep(1.2)

          album_data = MetadataHelper.get_album_info(mbid)

          sleep(1.2)

          cover_path = MetadataHelper.download_cover_art(album_data[:album_id])

          metadata = {
            song_id: song_data[0],
            song_name: song_data[1],
            artist_id: song_data[2]&.first&.[](0),
            artist_name: song_data[2]&.first&.[](2),
            album_id: album_data[:album_id],
            album_name: album_data[:album_name],
            release_date: album_data[:release_date],
            track_number: album_data[:track_number],
            cover_path: cover_path
          }
          is_recognized = true

        rescue NoMethodError => e
          puts "Warning: Incomplete API data from MusicBrainz (#{e.message})."
          is_recognized = false
          metadata = {}
        rescue OpenSSL::SSL::SSLError, EOFError, Errno::ECONNRESET => e
          puts "Network Error hitting MusicBrainz: #{e.message}. Proceeding with unrecognized record."
          is_recognized = false
          metadata = {}
        end

      else
        puts "Identification failed. Proceeding with unrecognized record."
        is_recognized = false
      end
    end

    artist = ArtistInfo.find_or_create_by!(
      artistName: metadata[:artist_name] || "Unknown Artist"
    ) do |a|
      a.artistID = metadata[:artist_id] || "art_#{SecureRandom.hex(12)}"
    end

    album = AlbumInfo.find_or_initialize_by(
      albumID: metadata[:album_id] || "alb_#{SecureRandom.hex(12)}"
    )
    album.update!(
      albumName: metadata[:album_name] || "Unknown Album",
      releaseDate: metadata[:release_date],
      coverPath: metadata[:cover_path]
    )

    AlbumArtist.find_or_create_by!(
      albumID: album.albumID,
      artistID: artist.artistID
    )

    release = AlbumRelease.find_or_initialize_by(
      releaseID: metadata[:album_id] ? "#{metadata[:album_id]}_rel" : "rel_#{SecureRandom.hex(12)}"
    )
    release.update!(
      albumID: album.albumID,
      releaseName: metadata[:album_name] || "Unknown Release"
    )

    song_id_to_use = metadata[:song_id] || "sng_#{SecureRandom.hex(12)}"
    song = SongInfo.find_or_initialize_by(songID: song_id_to_use)

    song.update!(
      songName: metadata[:song_name] || clean_filename,
      releaseID: release.releaseID,
      trackNumber: metadata[:track_number]
    )

    SongArtist.find_or_create_by!(
      songID: song.songID,
      artistID: artist.artistID
    )

    begin
      HashMatch.save_hash(new_hash, song.songID)
    rescue ActiveRecord::RecordNotUnique
      puts "Race condition caught: OS fired multiple events for one file."
      song.destroy
      FileUtils.rm(file_path) if File.exist?(file_path)
      return nil
    end

    target_folder = is_recognized ? 'library' : 'unrecognized'
    final_dir = Rails.root.join('storage', target_folder)
    FileUtils.mkdir_p(final_dir)

    extension = File.extname(file_path)
    new_filename = "#{song.songName}#{extension}"

    destination_path = final_dir.join(new_filename)
    FileUtils.mv(file_path, destination_path)

    puts "Successfully moved to: #{destination_path}"
    puts "Success: Saved '#{song.songName}' to the database!"

    Turbo::StreamsChannel.broadcast_append_to(
      "notifications_channel",
      target: "flash-notifications",
      html: "<div id='alert-#{song.songID}' class='alert alert-success alert-dismissible fade show shadow-sm' role='alert' style='pointer-events: auto; width: 350px;'>
               <strong>Success:</strong> Processed #{song.songName}
               <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
             </div>
             <script>
               setTimeout(() => {
                 let el = document.getElementById('alert-#{song.songID}');
                 if(el) {
                   el.classList.remove('show');
                   setTimeout(() => el.remove(), 150);
                 }
               }, 5000);
             </script>"
    )

    if is_recognized
      Turbo::StreamsChannel.broadcast_prepend_to(
        "notifications_channel",
        target: "recognized-songs-list",
        partial: "songs/song",
        locals: { song: song }
      )

      Turbo::StreamsChannel.broadcast_remove_to(
        "notifications_channel",
        target: "no-songs-msg"
      )
    end

    return song
  end
end
