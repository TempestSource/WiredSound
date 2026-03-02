require "test_helper"
require "fileutils"
require "securerandom"

class AudioProcessorTest < ActiveSupport::TestCase
  def setup
    @incoming_dir = Rails.root.join('storage', 'incoming_music')
    FileUtils.mkdir_p(@incoming_dir)

    @test_file_path = @incoming_dir.join("test_song.mp3").to_s

    File.write(@test_file_path, "dummy audio data #{SecureRandom.hex(10)}")

    @expected_hash = AudioHasher.call(@test_file_path)

    @metadata = {
      artist_name: "Beethoven",
      album_name: "Greatest Hits",
      song_name: "Symphony 9",
      artist_id: "art_test_#{SecureRandom.hex(4)}",
      album_id: "alb_test_#{SecureRandom.hex(4)}",
      song_id: "sng_test_#{SecureRandom.hex(4)}"
    }
  end

  def teardown
    FileUtils.rm_rf(Rails.root.join('storage', 'incoming_music'))
    FileUtils.rm_rf(Rails.root.join('storage', 'library'))
    FileUtils.rm_rf(Rails.root.join('storage', 'unrecognized'))
  end

  test "detects a new recognized file, saves it, and moves it to the library folder" do
    assert_difference 'SongInfo.count', 1 do
      AudioProcessor.call(@test_file_path, @metadata)
    end

    assert_equal "Symphony 9", SongInfo.last.songName

    assert_not File.exist?(@test_file_path), "File should be removed from incoming_music"
    assert File.exist?(Rails.root.join('storage', 'library', 'test_song.mp3')), "File should be in library folder"
  end

  test "detects an unrecognized file, saves it, and moves it to the unrecognized folder" do
    assert_difference 'SongInfo.count', 1 do
      AudioProcessor.call(@test_file_path, {})
    end

    assert_equal "test_song", SongInfo.last.songName

    assert_not File.exist?(@test_file_path), "File should be removed from incoming_music"
    assert File.exist?(Rails.root.join('storage', 'unrecognized', 'test_song.mp3')), "File should be in unrecognized folder"
  end

  test "detects a duplicate, skips the database, and deletes the incoming file" do
    artist = ArtistInfo.create!(artistID: "art_dup_#{SecureRandom.hex(4)}", artistName: "Dup Artist")
    album = AlbumInfo.create!(albumID: "alb_dup_#{SecureRandom.hex(4)}", albumName: "Dup Album", artistID: artist.artistID)
    song = SongInfo.create!(songID: "song_dup_#{SecureRandom.hex(4)}", songName: "Existing Song", albumID: album.albumID, artistID: artist.artistID)
    HashMatch.create!(hashVal: @expected_hash, songID: song.songID)

    assert_no_difference 'SongInfo.count' do
      AudioProcessor.call(@test_file_path, @metadata)
    end

    assert_not File.exist?(@test_file_path), "Duplicate file should be strictly deleted"
  end
end