require 'fileutils'
require 'securerandom'

class AudioProcessor
  def self.call(file_path, metadata = {})
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    match_record = ActiveRecord::Base.connection.execute(
      "SELECT songID FROM hash_match WHERE hash = '#{new_hash}' LIMIT 1"
    ).first

    if match_record
      matched_song = SongInfo.find_by(songID: match_record.first)
      puts "Duplicate: '#{matched_song.songName}' is already in the database."
      FileUtils.rm(file_path) if File.exist?(file_path)
      puts "Deleted duplicate file from incoming folder."
      return matched_song
    else
      puts "New file detected! Saving to database..."

      clean_filename = File.basename(file_path, ".*")
      is_recognized = !metadata.empty?

      if metadata.empty?
        # puts "Searching MusicBrainz for: '#{clean_filename}'..."
        # api_data = Metadata.get_search_result(file_path)
        # if api_data&.any?
        #   puts "Match found! Artist: #{api_data[:artist_name]} | Song: #{api_data[:song_name]}"
        #   metadata = api_data
        #   is_recognized = true
        # else

        puts "Metadata lookup disabled on this branch. Falling back to filename."
        is_recognized = false

        # end
      end

      artist = ArtistInfo.find_or_create_by!(
        artistName: metadata[:artist_name] || "Unknown Artist"
      ) do |a|
        a.artistID = metadata[:artist_id] || "art_#{SecureRandom.hex(12)}"
      end

      album = AlbumInfo.find_or_create_by!(
        albumName: metadata[:album_name] || "Unknown Album"
      ) do |a|
        a.albumID = metadata[:album_id] || "alb_#{SecureRandom.hex(12)}"
      end

      AlbumArtist.find_or_create_by!(
        albumID: album.albumID,
        artistID: artist.artistID
      )

      release = AlbumRelease.find_or_create_by!(
        releaseID: metadata[:album_id] ? "#{metadata[:album_id]}_rel" : "rel_#{SecureRandom.hex(12)}"
      ) do |r|
        r.albumID = album.albumID
        r.releaseName = metadata[:album_name] || "Unknown Release"
      end

      song = SongInfo.create!(
        songID: metadata[:song_id] || "sng_#{SecureRandom.hex(12)}",
        songName: metadata[:song_name] || clean_filename,
        releaseID: release.releaseID
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

      destination_path = final_dir.join(File.basename(file_path))
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
                     setTimeout(() => el.remove(), 150); // Wait for fade transition before removing from DOM
                   }
                 }, 5000);
               </script>"
      )
      return song
    end
  end
end