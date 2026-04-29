require "test_helper"
require "fileutils"
require "securerandom"
require "ostruct"

class AudioProcessorTest < ActiveSupport::TestCase
  def setup
    # 1. File System Setup
    @incoming_dir = Rails.root.join('storage', 'incoming_music')
    @library_dir = Rails.root.join('storage', 'library')
    @unrecognized_dir = Rails.root.join('storage', 'unrecognized')
    FileUtils.mkdir_p(@incoming_dir)
    FileUtils.mkdir_p(@library_dir)
    FileUtils.mkdir_p(@unrecognized_dir)

    @test_filename = "test_audio_#{SecureRandom.hex(4)}.mp3"
    @test_file_path = @incoming_dir.join(@test_filename).to_s
    File.write(@test_file_path, "dummy audio data #{SecureRandom.hex(10)}")

    # 2. Mock Data
    @mock_mbid = "sng_#{SecureRandom.hex(4)}"
    @mock_release_id = "mock_release_#{SecureRandom.hex(4)}"
    @mock_hash = SecureRandom.hex(16) # 32 character fake hash
    @mock_song_name = "Official API Song Title"
  end

  def teardown
    # Clean up test files safely
    FileUtils.rm_rf(@incoming_dir)
    FileUtils.rm_rf(@library_dir)
    FileUtils.rm_rf(@unrecognized_dir)
  end

  def with_services_stubbed(acoustid_result:, remote_hash_exists: false, &block)
    AudioHasher.stub :call, @mock_hash do
      AcoustidClient.stub :identify_audio, acoustid_result do
        GatekeeperClient.stub :remote_hash_exists?, remote_hash_exists do
          GatekeeperClient.stub :create_entry, true do
            LibraryBroadcaster.stub :broadcast, true do
              Dbupdater.stub :db_add, true do
                # Mock the local DB lookup
                mock_db_song = OpenStruct.new(songName: @mock_song_name)
                SongInfo.stub :find_by_songID, mock_db_song do
                  yield
                end
              end
            end
          end
        end
      end
    end
  end

  test "detects recognized file, hits Gatekeeper API for new hash, and moves to library" do
    with_services_stubbed(acoustid_result: { songID: @mock_mbid, releaseID: @mock_release_id }) do
      AudioProcessor.call(@test_file_path)
    end

    expected_library_path = @library_dir.join("#{@mock_mbid}.mp3")
    assert File.exist?(expected_library_path), "File should be moved to library"
  end

  test "detects recognized file, skips hydration if hash already exists remotely" do
    with_services_stubbed(acoustid_result: { songID: @mock_mbid, releaseID: @mock_release_id }, remote_hash_exists: true) do
      AudioProcessor.call(@test_file_path)
    end

    expected_library_path = @library_dir.join("#{@mock_mbid}.mp3")
    assert File.exist?(expected_library_path), "File should be moved to library"
  end

  test "deletes the incoming file if it is a physical duplicate in the library" do
    # Simulate the file already existing in the library
    existing_file = @library_dir.join("#{@mock_mbid}.mp3")
    File.write(existing_file, "existing content")

    with_services_stubbed(acoustid_result: { songID: @mock_mbid, releaseID: @mock_release_id }) do
      AudioProcessor.call(@test_file_path)
    end

    assert_not File.exist?(@test_file_path), "Incoming duplicate should be deleted"
  end

  test "moves file to unrecognized if AcoustID fails to identify it" do
    with_services_stubbed(acoustid_result: nil) do
      AudioProcessor.call(@test_file_path)
    end

    expected_unrecognized_path = @unrecognized_dir.join(@test_filename)
    assert File.exist?(expected_unrecognized_path), "File should be moved to unrecognized folder"
  end
end