require "test_helper"
require "fileutils"
require "securerandom"

class AudioProcessorTest < ActiveSupport::TestCase
  def setup
    @incoming_dir = Rails.root.join('storage', 'incoming_music')
    @library_dir = Rails.root.join('storage', 'library')
    @unrecognized_dir = Rails.root.join('storage', 'unrecognized')
    FileUtils.mkdir_p(@incoming_dir)
    FileUtils.mkdir_p(@library_dir)
    FileUtils.mkdir_p(@unrecognized_dir)

    @test_filename = "test_audio_#{SecureRandom.hex(4)}.mp3"
    @test_file_path = @incoming_dir.join(@test_filename).to_s

    # Create a fake audio file
    File.write(@test_file_path, "dummy audio data #{SecureRandom.hex(10)}")

    @mock_mbid = "sng_#{SecureRandom.hex(4)}"
    @mock_song_name = "Official API Song Title"

    # Create a reusable mock response object for HTTParty
    @mock_response_class = Struct.new(:code, :parsed_response) do
      def success?
        [200, 201].include?(code)
      end
    end
  end

  def teardown
    FileUtils.rm_rf(Rails.root.join('storage'))
  end

  test "detects a recognized file, hits the Gatekeeper API, and moves to library" do
    good_post = @mock_response_class.new(201, {})
    good_get = @mock_response_class.new(200, { "songName" => @mock_song_name })

    # Intercept AcoustID and HTTParty to return our fake success data
    AcoustidClient.stub :identify_audio, @mock_mbid do
      HTTParty.stub :post, ->(*args) { good_post } do
        HTTParty.stub :get, ->(*args) { good_get } do
          AudioProcessor.call(@test_file_path)
        end
      end
    end

    expected_library_path = @library_dir.join("#{@mock_song_name}.mp3")

    assert File.exist?(expected_library_path), "File should be moved to the library with the official API name"
    assert_not File.exist?(@test_file_path), "Original file should be removed from incoming"
  end

  test "deletes the incoming file if it is a physical duplicate in the library" do
    # Create the duplicate file in the library first
    existing_file = @library_dir.join("#{@mock_song_name}.mp3")
    File.write(existing_file, "existing content")

    good_post = @mock_response_class.new(409, {}) # 409 Conflict = Already exists in DB
    good_get = @mock_response_class.new(200, { "songName" => @mock_song_name })

    AcoustidClient.stub :identify_audio, @mock_mbid do
      HTTParty.stub :post, ->(*args) { good_post } do
        HTTParty.stub :get, ->(*args) { good_get } do
          AudioProcessor.call(@test_file_path)
        end
      end
    end

    assert_not File.exist?(@test_file_path), "Incoming file should be deleted because it is a physical duplicate"
    assert_equal "existing content", File.read(existing_file), "Original library file should remain untouched"
  end

  test "moves file to unrecognized if API rejects it or AcoustID fails" do
    bad_post = @mock_response_class.new(500, {})

    # Mock AcoustID returning a valid ID, but the API rejecting it
    AcoustidClient.stub :identify_audio, @mock_mbid do
      HTTParty.stub :post, ->(*args) { bad_post } do
        AudioProcessor.call(@test_file_path)
      end
    end

    expected_unrecognized_path = @unrecognized_dir.join(@test_filename)

    assert File.exist?(expected_unrecognized_path), "File should be moved to the unrecognized folder"
    assert_not File.exist?(@test_file_path), "Original file should be removed from incoming"
  end
end