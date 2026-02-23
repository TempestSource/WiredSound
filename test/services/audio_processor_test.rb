require "test_helper"

class AudioProcessorTest < ActiveSupport::TestCase
  def setup
    @temp_file = Tempfile.new(%w[test_song .mp3])
    @temp_file.write("audio data")
    @temp_file.rewind

    @expected_hash = AudioHasher.call(@temp_file.path)

    @metadata = {
      artist_name: "Beethoven",
      album_name: "Greatest Hits",
      song_name: "Symphony 9"
    }
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  test "detects a new file and saves it to the database" do
    assert_difference 'SongInfo.count', 1 do
      assert_output(/New file detected!/) do
        AudioProcessor.call(@temp_file.path, @metadata)
      end
    end

    assert_equal "Symphony 9", SongInfo.last.songName
  end

  test "detects a duplicate and does not create new records" do
    artist = ArtistInfo.create!(artistID: "art_dup", artistName: "Dup Artist")
    album = AlbumInfo.create!(albumID: "alb_dup", albumName: "Dup Album", artistID: artist.artistID)
    song = SongInfo.create!(songID: "song_dup", songName: "Existing Song", albumID: album.albumID, artistID: artist.artistID)
    HashMatch.create!(hashVal: @expected_hash, songID: song.songID)

    assert_no_difference 'SongInfo.count' do
      assert_output(/Duplicate: 'Existing Song'/) do
        AudioProcessor.call(@temp_file.path, @metadata)
      end
    end
  end
end