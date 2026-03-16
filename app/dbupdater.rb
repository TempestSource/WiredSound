require_relative 'metadata'

class DBUpdater
  def initialize
    @mb = Metadata.new
  end

  def table_data(song_id, release_id)
    song_data = @mb.process_song(song_id)
    release_data = @mb.process_release(release_id)

    [
      song_info(song_id, release_id, song_data[1], release_data),
      album_releases(release_id, release_data[1]),
      album_info(release_data),
      album_artists(release_data[1], release_data[4]),
      song_artists(song_id, song_data[2]),
      artist_info(song_data[2])
    ]
  end

  def song_info(song_id, release_id, song_name, release_data)
    this_song = release_data[6].find { |cur| cur[2] == song_name }
    [
      song_id,
      song_name,
      release_id,
      this_song[1] # trackNumber
    ]
  end

  def album_releases(release_id, album_id)
    [
      release_id,
      album_id
    ]
  end

  def album_info(release_data)
    [
      release_data[1], # albumID
      release_data[3], # albumName
      release_data[2], # albumType
      'TODO: cover path',
      release_data[5] # albumRelease
    ]
  end

  def album_artists(album_id, artists)
    artists.map do |cur|
      [
        album_id,
        cur
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