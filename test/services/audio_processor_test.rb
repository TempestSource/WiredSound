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
    File.write(@test_file_path, "dummy audio data")

    # 2. Mock Data
    @mock_mbid = "sng_#{SecureRandom.hex(4)}"
    @mock_release_id = "rel_#{SecureRandom.hex(4)}"
    @mock_hash = SecureRandom.hex(16)
  end

  def teardown
    FileUtils.rm_rf(@incoming_dir)
    FileUtils.rm_rf(@library_dir)
    FileUtils.rm_rf(@unrecognized_dir)
  end

  def with_services_stubbed(acoustid_result:, remote_hash_exists: false, &block)
    AudioHasher.stub :call, @mock_hash do
      AcoustidClient.stub :identify_audio, acoustid_result do
        MusicbrainzHelper.stub :find_release_by_recording_id, @mock_release_id do
          GatekeeperClient.stub :remote_hash_exists?, remote_hash_exists do
            LibraryBroadcaster.stub :broadcast, true do
              yield
            end
          end
        end
      end
    end
  end

  test "identifies file and triggers remote hydration without local db_add" do
    with_services_stubbed(acoustid_result: { songID: @mock_mbid, releaseID: @mock_release_id }) do
      GatekeeperClient.stub :create_entry, ->(raw_hash:, song_id:, release_id:) {
        assert_equal @mock_hash, raw_hash
        assert_equal @mock_mbid, song_id
        true
      } do
        AudioProcessor.call(@test_file_path)
      end
    end

    assert File.exist?(@library_dir.join("#{@mock_mbid}.mp3")), "File should be moved to library"
  end

  test "skips hydration if remote API already knows the hash" do
    with_services_stubbed(acoustid_result: { songID: @mock_mbid, releaseID: @mock_release_id }, remote_hash_exists: true) do
      GatekeeperClient.stub :create_entry, ->(*) { flunk "Should not hydrate if known remotely" } do
        AudioProcessor.call(@test_file_path)
      end
    end
    assert File.exist?(@library_dir.join("#{@mock_mbid}.mp3"))
  end

  test "moves to unrecognized when no match found" do
    with_services_stubbed(acoustid_result: nil) do
      AudioProcessor.call(@test_file_path)
    end
    assert File.exist?(@unrecognized_dir.join(@test_filename))
  end
end