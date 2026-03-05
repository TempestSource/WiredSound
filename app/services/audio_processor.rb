require 'fileutils'
require 'securerandom'
require Rails.root.join('server', 'metadata')

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
        puts "Searching MusicBrainz for: '#{clean_filename}'..."
        api_data = Metadata.get_search_result(clean_filename)

        if api_data&.any?
          puts "Match found! Artist: #{api_data[:artist_name]} | Song: #{api_data[:song_name]}"
          metadata = api_data
          is_recognized = true
        else
          puts "No match found on MusicBrainz. Falling back to filename."
          is_recognized = false
        end
      end

      artist = ArtistInfo.find_or_create_by!(
        artistName: metadata[:artist_name] || "Unknown Artist"
      ) do |a|
        a.artirstID = metadata[:artist_id] || "art_#{SecureRandom.hex(12)}"
      end

      album = AlbumInfo.find_or_create_by!(
        albumName: metadata[:album_name] || "Unknown Album"
      ) do |a|
        a.albumID = metadata[:album_id] || "alb_#{SecureRandom.hex(12)}"
      end

      AlbumArtist.find_or_create_by!(
        albumID: album.albumID,
        artistID: artist.artirstID
      )

      release = AlbumRelease.find_or_create_by!(
        albumID: album.albumID
      ) do |r|
        r.releaseID = metadata[:release_id] || "rel_#{SecureRandom.hex(12)}"
      end

      song = SongInfo.create!(
        songID: metadata[:song_id] || "sng_#{SecureRandom.hex(12)}",
        songName: metadata[:song_name] || clean_filename,
        releaseID: release.releaseID
      )

      SongArtist.find_or_create_by!(
        songID: song.songID,
        artistID: artist.artirstID
      )

      begin
        HashMatch.save_hash(new_hash, song.songID)
      rescue ActiveRecord::RecordNotUnique
        puts "Race condition caught: OS fired multiple events for one file."
        SongArtist.where(songID: song.songID).destroy_all
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

      return song
    end
  end
end