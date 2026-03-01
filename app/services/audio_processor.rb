require 'fileutils'
require 'securerandom'
require Rails.root.join('server', 'metadata')

class AudioProcessor
  def self.call(file_path, metadata = {})
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    match = HashMatch.find_by(hashVal: new_hash)

    if match
      puts "Duplicate: '#{match.song_info.songName}' is already in the database."

      FileUtils.rm(file_path) if File.exist?(file_path)
      puts "Deleted duplicate file from incoming folder."

      return match.song_info
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
        artistID: metadata[:artist_id] || "art_#{SecureRandom.hex(12)}",
        artistName: metadata[:artist_name] || "Unknown Artist"
      )

      album = AlbumInfo.find_or_create_by!(
        albumID: metadata[:album_id] || "alb_#{SecureRandom.hex(12)}",
        artistID: artist.artistID
      ) do |a|
        a.albumName = metadata[:album_name] || "Unknown Album"
        a.albumYear = metadata[:album_year]
        a.coverPath = metadata[:cover_path]
      end

      song = SongInfo.create!(
        songID: metadata[:song_id] || "sng_#{SecureRandom.hex(12)}",
        songName: metadata[:song_name] || clean_filename,
        albumID: album.albumID,
        artistID: artist.artistID
      )

      HashMatch.create!(hashVal: new_hash, songID: song.songID)

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