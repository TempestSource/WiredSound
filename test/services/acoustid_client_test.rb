require "test_helper"
require "open3"
require "ostruct"

class AcoustidClientTest < ActiveSupport::TestCase
  def setup
    @test_file = "test_audio.mp3"
    @mock_fingerprint = "AQAAAAAAA..."
    @mock_duration = 180
    @mock_mbid = "sng_123"
    @mock_release_id = "rel_456"

    # Ensure API Key is "present" for the test logic
    ENV['ACOUSTID_API_KEY'] = "test_key"

    @mock_response = Struct.new(:code, :body, :success?, :parsed_response)
  end

  # --- generate_fingerprint Tests ---

  test "generate_fingerprint captures JSON from fpcalc" do
    mock_stdout = { "duration" => @mock_duration, "fingerprint" => @mock_fingerprint }.to_json
    mock_status = OpenStruct.new(success?: true)

    Open3.stub :capture3, [mock_stdout, "", mock_status] do
      result = AcoustidClient.generate_fingerprint(@test_file)

      assert_equal @mock_duration, result[:duration]
      assert_equal @mock_fingerprint, result[:fingerprint]
    end
  end

  test "generate_fingerprint returns nil if fpcalc fails" do
    mock_status = OpenStruct.new(success?: false)

    Open3.stub :capture3, ["", "command not found", mock_status] do
      assert_nil AcoustidClient.generate_fingerprint(@test_file)
    end
  end

  # --- fetch_mbid Tests ---

  test "fetch_mbid returns song and release IDs on successful match" do
    api_body = {
      "status" => "ok",
      "results" => [{
                      "recordings" => [{
                                         "id" => @mock_mbid,
                                         "releases" => [{ "id" => @mock_release_id, "title" => "Test Album" }]
                                       }]
                    }]
    }.to_json

    success_resp = @mock_response.new(200, api_body, true, JSON.parse(api_body))

    HTTParty.stub :get, success_resp do
      result = AcoustidClient.fetch_mbid(@mock_duration, @mock_fingerprint)
      assert_equal @mock_mbid, result[:songID]
      assert_equal @mock_release_id, result[:releaseID]
    end
  end

  test "fetch_mbid handles partial matches with missing release data" do
    api_body = {
      "status" => "ok",
      "results" => [{
                      "recordings" => [{ "id" => @mock_mbid }]
                    }]
    }.to_json

    partial_resp = @mock_response.new(200, api_body, true, JSON.parse(api_body))

    HTTParty.stub :get, partial_resp do
      result = AcoustidClient.fetch_mbid(@mock_duration, @mock_fingerprint)
      assert_equal @mock_mbid, result[:songID]
      assert_nil result[:releaseID]
    end
  end

  # --- identify_audio Integration Test ---

  test "identify_audio orchestrates fingerprinting and fetching" do
    mock_audio_data = { duration: @mock_duration, fingerprint: @mock_fingerprint }
    mock_api_result = { songID: @mock_mbid, releaseID: @mock_release_id }

    AcoustidClient.stub :generate_fingerprint, mock_audio_data do
      AcoustidClient.stub :fetch_mbid, mock_api_result do
        result = AcoustidClient.identify_audio(@test_file)
        assert_equal @mock_mbid, result[:songID]
      end
    end
  end

  # --- find_release_for_track Tests ---

  test "find_release_for_track searches MusicBrainz and returns first release ID" do
    mb_body = {
      "recordings" => [{
                         "releases" => [{ "id" => @mock_release_id, "title" => "Search Result Album" }]
                       }]
    }.to_json

    mb_resp = @mock_response.new(200, mb_body, true, JSON.parse(mb_body))

    HTTParty.stub :get, mb_resp do
      result = AcoustidClient.find_release_for_track("Hurt", "Johnny Cash")
      assert_equal @mock_release_id, result
    end
  end
end