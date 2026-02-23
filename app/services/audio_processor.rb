class AudioProcessor
  def self.call(file_path, metadata = {})
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    match = HashMatch.find_by(hashVal: new_hash)

    if match
      puts "Duplicate: '#{match.song_info.songName}' is already in the database."
      return match.song_info
    else
      puts "New file detected! Saving to database..."


      artist = ArtistInfo.find_or_create_by!(
        artistID: metadata[:artist_id] || "temp_art_#{Time.now.to_i}",
        artistName: metadata[:artist_name] || "Unknown Artist"
      )

      album = AlbumInfo.find_or_create_by!(
        albumID: metadata[:album_id] || "temp_alb_#{Time.now.to_i}",
        albumName: metadata[:album_name] || "Unknown Album",
        artistID: artist.artistID
      )

      song = SongInfo.create!(
        songID: metadata[:song_id] || "temp_song_#{Time.now.to_i}",
        songName: metadata[:song_name] || File.basename(file_path, ".*"),
        artistID: artist.artistID,
        albumID: album.albumID
      )

      HashMatch.create!(hashVal: new_hash, songID: song.songID)

      puts "Success: Saved '#{song.songName}' to the database!"
      return song
    end
  end
end