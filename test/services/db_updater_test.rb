require "test_helper"

class DbupdaterTest < ActiveSupport::TestCase
  def setup
    @song_id = "test-song-id-123"
    @release_id = "test-release-id-456"
    @hash_value = "a" * 32

    # Define the dummy data that the Metadata service would usually return
    @mock_song_data = [
      nil, # data[0] unused
      "Magic Girl and Chocolate", # data[1] song_name
      [["art-1", "Person", "PinocchioP", "JP", "2009"]] # data[2] artist_info
    ]

    @mock_release_data = [
      nil, # data[0] unused
      "alb-1", # data[1] albumID
      "Album", # data[2] albumType
      "META",  # data[3] albumName
      ["art-1"], # data[4] album_artists
      "2023-05-17", # data[5] releaseDate
      [["unused", 5, "Magic Girl and Chocolate"]] # data[6] tracks for song_info
    ]
  end

  test "db_add creates all associated records correctly" do
    # Stub the Metadata class methods that Dbupdater calls internally
    Metadata.stub :process_song, @mock_song_data do
      Metadata.stub :process_release, @mock_release_data do

        # Verify that calling db_add increases the count of all our tables
        assert_difference -> { SongInfo.count } => 1,
                          -> { ArtistInfo.count } => 1,
                          -> { AlbumInfo.count } => 1,
                          -> { AlbumRelease.count } => 1,
                          -> { HashMatch.count } => 1 do

          Dbupdater.db_add(@hash_value, @song_id, @release_id)
        end
      end
    end

    # Verify the data was mapped to the correct columns
    song = SongInfo.find_by(songID: @song_id)
    assert_equal "Magic Girl and Chocolate", song.songName
    assert_equal 5, song.trackNumber

    artist = ArtistInfo.find_by(artistID: "art-1")
    assert_equal "PinocchioP", artist.artistName

    album = AlbumInfo.find_by(albumID: "alb-1")
    assert_equal "META", album.albumName

    hash_match = HashMatch.find_by(raw_hash: @hash_value)
    assert_equal @song_id, hash_match.songID
  end

  test "add_artists does not create duplicate artists" do
    # Pre-create the artist
    ArtistInfo.create!(artistID: "art-1", artistName: "PinocchioP")

    artist_data = [["art-1", "Person", "PinocchioP", "JP", "2009"]]

    assert_no_difference "ArtistInfo.count" do
      Dbupdater.add_artists(artist_data)
    end
  end
end