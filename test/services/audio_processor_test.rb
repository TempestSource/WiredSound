require "test_helper"
require "fileutils"
require "securerandom"

class AudioProcessorTest < ActiveSupport::TestCase
  def setup
    @incoming_dir = Rails.root.join('storage', 'incoming_music')
    @library_dir = Rails.root.join('storage', 'library')
    FileUtils.mkdir_p(@incoming_dir)
    FileUtils.mkdir_p(@library_dir)

    @test_filename = "test_audio_#{SecureRandom.hex(4)}.mp3"
    @test_file_path = @incoming_dir.join(@test_filename).to_s

    File.write(@test_file_path, "dummy audio data #{SecureRandom.hex(10)}")
    @expected_hash = AudioHasher.call(@test_file_path)

    @metadata = {
      artist_name: "Beethoven",
      album_name: "Greatest Hits",
      song_name: "Symphony 9",
      artist_id: "art_#{SecureRandom.hex(4)}",
      album_id: "alb_#{SecureRandom.hex(4)}",
      song_id: "sng_#{SecureRandom.hex(4)}"
    }
  end

  def teardown
    FileUtils.rm_rf(Rails.root.join('storage'))
  end

  test "detects a new recognized file and moves it to the library" do
    MetadataHelper.stub :search_by_filename, @metadata[:song_id] do
      MetadataHelper.stub :get_album_info, { album_id: @metadata[:album_id], album_name: @metadata[:album_name] } do

        AudioProcessor.call(@test_file_path, @metadata)

        expected_path = Rails.root.join('storage', 'library', "Symphony 9.mp3")
        assert File.exist?(expected_path), "File should be renamed to official song name"
        assert_not File.exist?(@test_file_path)
      end
    end
  end

  test "detects an unrecognized file and moves it to the unrecognized folder" do
    MetadataHelper.stub :search_by_filename, nil do

      AudioProcessor.call(@test_file_path, {})

      match = HashMatch.find_by(raw_hash: @expected_hash)
      song = SongInfo.find(match.songID)

      expected_path = Rails.root.join('storage', 'unrecognized', "#{song.songName}.mp3")
      assert File.exist?(expected_path)
      assert_not File.exist?(@test_file_path)
    end
  end

  test "detects a true duplicate and deletes the incoming file" do
    album = AlbumInfo.create!(albumID: "alb_dup", albumName: "Dup")
    rel = AlbumRelease.create!(releaseID: "rel_dup", albumID: album.albumID)
    song = SongInfo.create!(songID: "sng_dup", songName: "Duplicate Track", releaseID: rel.releaseID)
    HashMatch.create!(raw_hash: @expected_hash, songID: song.songID)

    existing_file = @library_dir.join("Duplicate Track.mp3")
    File.write(existing_file, "existing content")

    assert_no_difference 'SongInfo.count' do
      AudioProcessor.call(@test_file_path, @metadata)
    end

    assert_not File.exist?(@test_file_path), "Incoming file should be deleted"
    assert File.exist?(existing_file), "Original library file should remain untouched"
  end

  test "detects a missing file and restores it from incoming" do
    album = AlbumInfo.create!(albumID: "alb_res", albumName: "Res")
    rel = AlbumRelease.create!(releaseID: "rel_res", albumID: album.albumID)
    song = SongInfo.create!(songID: "sng_res", songName: "Restored Track", releaseID: rel.releaseID)
    HashMatch.create!(raw_hash: @expected_hash, songID: song.songID)

    restored_path = @library_dir.join("Restored Track.mp3")
    File.delete(restored_path) if File.exist?(restored_path)

    AudioProcessor.call(@test_file_path, @metadata)

    assert File.exist?(restored_path), "Missing physical file should have been restored"
    assert_not File.exist?(@test_file_path)
  end
end