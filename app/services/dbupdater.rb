# frozen_string_literal: true

class Dbupdater
  class << self

    def db_add(hash_value, song_id, release_id)
      data = table_data(song_id, release_id)

      add_artists(data[5])
      add_album(data[2])
      add_album_artists(data[3])
      add_release(data[1])
      add_song(data[0])
      add_song_artists(data[4])
      add_hash_match(hash_value, song_id)
    end

    def add_artists(data)
      data.each do |artist|
        # Use initialize so we can update existing "Unknown" records
        a = ArtistInfo.find_or_initialize_by(artistID: artist[0] || '')

        a.artistType = artist[1] || ''
        a.artistName = artist[2] || ''
        a.artistCountry = artist[3] || ''
        a.artistBegin = artist[4] || ''

        a.save!
      end
    end

    def add_album(data)
      a = AlbumInfo.find_or_initialize_by(albumID: data[0] || '')

      a.albumName = data[1] || ''
      a.albumType = data[2] || ''
      if data[3].present?
        a.coverPath = data[3]
        # NEW PRINT STATEMENT:
        puts "DEBUG: Setting cover path for '#{a.albumName}' to: #{a.coverPath}"
      end
      a.releaseDate = data[4] || ''
      a.save!
    end

    def add_album_artists(data)
      data.each do |row|
        album_id = row[0]
        artist_id = row[1]

        ArtistInfo.find_or_create_by!(artistID: artist_id) do |a|
          a.artistName = 'Unknown Album Artist'
        end

        AlbumArtist.find_or_create_by!(
          albumID: album_id,
          artistID: artist_id
        )
      end
    end

    def add_release(data)
      AlbumRelease.find_or_create_by!(
        releaseID: data[0] || ''
      ) do |a|
        a.albumID = data[1] || ''
        # TODO: releaseName
      end
    end

    def add_song(data)
      SongInfo.find_or_create_by!(
        songID: data[0] || ''
      ) do |a|
        a.songName = data[1] || ''
        a.releaseID = AlbumRelease.find_by_releaseID(data[2]).releaseID || ''
        a.trackNumber = data[3] || ''
      end
    end

    def add_song_artists(data)
      data.each do |row|
        song_id = row[0]
        artist_id = row[1]

        ArtistInfo.find_or_create_by!(artistID: artist_id) do |a|
          a.artistName = 'Unknown Song Artist'
        end

        SongArtist.find_or_create_by!(
          songID: song_id,
          artistID: artist_id
        )
      end
    end

    def add_hash_match(hash_value, song_id)
      HashMatch.find_or_create_by!(
        raw_hash: hash_value || ''
      ) do |a|
        a.songID = SongInfo.find_by_songID(song_id).songID || ''
      end
    end

    def table_data(song_id, release_id)
      song_data = Metadata.process_song(song_id)
      release_data = Metadata.process_release(release_id)


      all_artists = (song_data[2] + release_data[4]).uniq

      [
        song_info(song_id, release_id, song_data[1], release_data),
        album_releases(release_id, release_data[1]),
        album_info(release_data),
        album_artists(release_data[1], release_data[4]),
        song_artists(song_id, song_data[2]),
        artist_info(all_artists)
      ]
    end

    def song_info(song_id, release_id, song_name, release_data)
      this_song = release_data[6].find { |cur| cur[0] == song_id }

      [
        song_id,
        song_name,
        release_id,
        this_song ? this_song[1] : 0 # Keep your excellent safeguard!
      ]
    end

    def album_releases(release_id, album_id)
      [
        release_id,
        album_id
      ]
    end

    def album_info(release_data)
      release_id = release_data[0]
      [
        release_data[1], # albumID
        release_data[3], # albumName
        release_data[2], # albumType
        "/covers/#{release_id}.jpg",
        release_data[5] # albumRelease (Date)
      ]
    end

    def album_artists(album_id, artists)
      artists.map do |cur|
        [
          album_id,
          cur[0]
        ]
      end
    end

    def song_artists(song_id, artists)
      artists.map do |cur|
        [
          song_id,
          cur[0] # artistID
        ]
      end
    end

    def artist_info(artists)
      artists.map do |cur|
        [
          cur[0], # artistID
          cur[1], # artistType
          cur[2], # artistName
          cur[3], # artistCountry
          cur[4] # artistBegin
        ]
      end
    end

  end
end