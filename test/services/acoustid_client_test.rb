require "test_helper"
require "json"

class AcoustidClientTest < ActiveSupport::TestCase
  setup do
    # Temporarily set a fake API key so our tests don't fail if the .env file is missing locally
    @original_api_key = ENV['ACOUSTID_API_KEY']
    ENV['ACOUSTID_API_KEY'] = 'test_dummy_api_key'
  end

  teardown do
    # Restore the original environment variable after tests complete
    ENV['ACOUSTID_API_KEY'] = @original_api_key
  end

  # --- Our Custom Pure-Ruby Stub Helper ---
  # We built this from scratch instead of relying on external gems!
  def with_stub(target, method_name, return_value)
    # 1. Save the original method
    original_method = target.method(method_name)

    # 2. Overwrite it to return our fake data (ignoring any arguments passed)
    target.define_singleton_method(method_name) do |*args, **kwargs, &block|
      return_value
    end

    # 3. Run the test
    yield
  ensure
    # 4. Always restore the original method, even if the test fails!
    target.define_singleton_method(method_name, &original_method)
  end

  # --- Step 1: Testing fpcalc (generate_fingerprint) ---

  test "generate_fingerprint returns duration and fingerprint on success" do
    mock_status = Struct.new(:success?).new(true)
    mock_stdout = { "duration" => 215, "fingerprint" => "AQADt_fake_fingerprint_data" }.to_json

    with_stub(Open3, :capture3, [mock_stdout, "", mock_status]) do
      result = AcoustidClient.generate_fingerprint("fake_song.mp3")

      assert_not_nil result
      assert_equal 215, result[:duration]
      assert_equal "AQADt_fake_fingerprint_data", result[:fingerprint]
    end
  end

  test "generate_fingerprint returns nil when fpcalc fails" do
    mock_status = Struct.new(:success?).new(false)

    with_stub(Open3, :capture3, ["", "ERROR: Invalid data found", mock_status]) do
      assert_nil AcoustidClient.generate_fingerprint("corrupted_file.mp3")
    end
  end

  # --- Step 2: Testing the API (fetch_mbid) ---

  test "fetch_mbid returns a MusicBrainz ID on successful match" do
    mock_body = {
      "status" => "ok",
      "results" => [
        { "recordings" => [{ "id" => "a1e4bb2b-04cf-48ba-a21d-fakeid123" }] }
      ]
    }.to_json
    mock_response = Struct.new(:body).new(mock_body)

    with_stub(HTTParty, :get, mock_response) do
      mbid = AcoustidClient.fetch_mbid(215, "AQADt_fake_fingerprint_data")
      assert_equal "a1e4bb2b-04cf-48ba-a21d-fakeid123", mbid
    end
  end

  test "fetch_mbid returns nil when API returns zero matches" do
    mock_body = { "status" => "ok", "results" => [] }.to_json
    mock_response = Struct.new(:body).new(mock_body)

    with_stub(HTTParty, :get, mock_response) do
      assert_nil AcoustidClient.fetch_mbid(215, "AQADt_unrecognized_data")
    end
  end

  test "fetch_mbid returns nil when the API key is missing" do
    ENV['ACOUSTID_API_KEY'] = nil
    assert_nil AcoustidClient.fetch_mbid(215, "AQADt_fake_fingerprint_data")
  end

  # --- Step 3: Testing the Wrapper (identify_audio) ---

  test "identify_audio successfully chains fingerprinting and fetching" do
    with_stub(AcoustidClient, :generate_fingerprint, { duration: 215, fingerprint: "AQADt_fake" }) do
      with_stub(AcoustidClient, :fetch_mbid, "master-mbid-123") do

        result = AcoustidClient.identify_audio("awesome_song.mp3")
        assert_equal "master-mbid-123", result

      end
    end
  end
end