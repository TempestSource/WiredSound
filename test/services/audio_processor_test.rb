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

    File.write(@test_file_path, "dummy audio data #{SecureRandom.hex(10)}")

    @mock_mbid = "sng_#{SecureRandom.hex(4)}"
    @mock_song_name = "Official API Song Title"
    AudioProcessor.reset_token!
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

    AudioProcessor.stub :get_auth_token, "fake_test_token" do
      AcoustidClient.stub :identify_audio, @mock_mbid do
        HTTParty.stub :post, ->(*args) { good_post } do
          HTTParty.stub :get, ->(*args) { good_get } do
            AudioProcessor.call(@test_file_path)
          end
        end
      end
    end

    expected_library_path = @library_dir.join("#{@mock_song_name}.mp3")
    assert File.exist?(expected_library_path), "File should be moved to the library"
  end

  test "deletes the incoming file if it is a physical duplicate in the library" do
    existing_file = @library_dir.join("#{@mock_song_name}.mp3")
    File.write(existing_file, "existing content")

    duplicate_post = @mock_response_class.new(409, {})
    good_get = @mock_response_class.new(200, { "songName" => @mock_song_name })

    AudioProcessor.stub :get_auth_token, "fake_test_token" do
      AcoustidClient.stub :identify_audio, @mock_mbid do
        HTTParty.stub :post, ->(*args) { duplicate_post } do
          HTTParty.stub :get, ->(*args) { good_get } do
            AudioProcessor.call(@test_file_path)
          end
        end
      end
    end

    assert_not File.exist?(@test_file_path), "Incoming duplicate should be deleted"
  end

  test "moves file to unrecognized if API rejects it or AcoustID fails" do
    bad_post = @mock_response_class.new(500, {})

    AudioProcessor.stub :get_auth_token, "fake_test_token" do
      AcoustidClient.stub :identify_audio, @mock_mbid do
        HTTParty.stub :post, ->(*args) { bad_post } do
          AudioProcessor.call(@test_file_path)
        end
      end
    end

    expected_unrecognized_path = @unrecognized_dir.join(@test_filename)
    assert File.exist?(expected_unrecognized_path), "File should be in unrecognized"
  end
end