require 'fileutils'
require 'securerandom'

class AudioProcessor
  def self.call(file_path, metadata = {})
    puts "--- Processing Audio File ---"

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    match_record = HashMatch.find_by(raw_hash: new_hash)

    if match_record
      matched_song = match_record.song_info

      if matched_song
        library_path = Rails.root.join('storage', 'library', "#{matched_song.songName}.mp3")
        unrecognized_path = Rails.root.join('storage', 'unrecognized', "#{matched_song.songName}.mp3")

        if File.exist?(library_path) || File.exist?(unrecognized_path)
          puts "Duplicate: '#{matched_song.songName}' is already in the database and on disk."
          FileUtils.rm(file_path) if File.exist?(file_path)
          return matched_song
        else
          puts "Record found, but physical file missing. Restoring file..."
          target_dir = Rails.root.join('storage', 'library')
          FileUtils.mkdir_p(target_dir)
          FileUtils.mv(file_path, target_dir.join("#{matched_song.songName}.mp3"))
        end
        return matched_song
      else
        puts "Warning: Ghost hash detected. Deleting corrupted hash record..."
        match_record.destroy
      end
    end

    puts "New file detected! Fetching Metadata..."
    clean_filename = File.basename(file_path, ".*")
    is_recognized = metadata.present?

    if metadata.empty?
      mbid = AcoustidClient.identify_audio(file_path) || MetadataHelper.search_by_filename(clean_filename)

      if mbid.present?
        begin
          mb = Metadata.new
          song_data = mb.process_song(mbid)
          sleep(1.2) # To avoid rate limits
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
        rescue StandardError => e
          puts "API or Network Error hitting MusicBrainz: #{e.message}. Proceeding as unrecognized."
          is_recognized = false
          metadata = {}
        end
      end
    end

    artist = ArtistInfo.find_or_create_by!(artistID: metadata[:artist_id] || "art_#{SecureRandom.hex(12)}") do |a|
      a.artistName = metadata[:artist_name] || "Unknown Artist"
    end

    album = AlbumInfo.find_or_create_by!(albumID: metadata[:album_id] || "alb_#{SecureRandom.hex(12)}") do |a|
      a.albumName = metadata[:album_name] || "Unknown Album"
      a.releaseDate = metadata[:release_date]
      a.coverPath = metadata[:cover_path]
    end

    AlbumArtist.find_or_create_by!(albumID: album.albumID, artistID: artist.artistID)

    release = AlbumRelease.find_or_create_by!(releaseID: metadata[:album_id] ? "#{metadata[:album_id]}_rel" : "rel_#{SecureRandom.hex(12)}") do |r|
      r.albumID = album.albumID
      r.releaseName = metadata[:album_name] || "Unknown Release"
    end

    song = SongInfo.create!(
      songID: metadata[:song_id] || "sng_#{SecureRandom.hex(12)}",
      songName: metadata[:song_name] || clean_filename,
      releaseID: release.releaseID,
      trackNumber: metadata[:track_number]
    )

    SongArtist.find_or_create_by!(songID: song.songID, artistID: artist.artistID)

    begin
      HashMatch.create!(raw_hash: new_hash, songID: song.songID)
    rescue ActiveRecord::RecordNotUnique
      song.destroy
      FileUtils.rm(file_path) if File.exist?(file_path)
      return nil
    end

    target_folder = is_recognized ? 'library' : 'unrecognized'
    final_dir = Rails.root.join('storage', target_folder)
    FileUtils.mkdir_p(final_dir)
    destination_path = final_dir.join("#{song.songName}#{File.extname(file_path)}")
    FileUtils.mv(file_path, destination_path)


    Turbo::StreamsChannel.broadcast_append_to(
      "notifications_channel",
      target: "flash-notifications",
      partial: "songs/success_alert",
      locals: { song: song }
    )

    if is_recognized
      Turbo::StreamsChannel.broadcast_prepend_to(
        "notifications_channel",
        target: "recognized-songs-list",
        partial: "songs/song",
        locals: { song: song }
      )
    end

    return song
  end
end