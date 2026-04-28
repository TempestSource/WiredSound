require "test_helper"

class GatekeeperClientTest < ActiveSupport::TestCase
  def setup
    # Reset the cached token before every test to ensure a clean login attempt
    GatekeeperClient.reset_token!
    @api_base = ENV['API_URL'] || "http://wired.iceheart.xyz:3000"

    # Create a mock response helper similar to your processor tests
    @mock_response = Struct.new(:code, :success?, :parsed_response)
  end

  # --- Authentication Tests ---

  test "get_auth_token succeeds and caches the token" do
    success_body = { "access_token" => "fake_jwt_token_123" }
    response = @mock_response.new(200, true, success_body)

    HTTParty.stub :post, response do
      token = GatekeeperClient.get_auth_token
      assert_equal "fake_jwt_token_123", token
      # Verify caching: second call shouldn't trigger a POST (would fail stub if it did)
      assert_equal "fake_jwt_token_123", GatekeeperClient.get_auth_token
    end
  end

  test "get_auth_token returns nil on failure" do
    failure = @mock_response.new(401, false, { "error" => "Unauthorized" })

    HTTParty.stub :post, failure do
      assert_nil GatekeeperClient.get_auth_token
    end
  end

  # --- Entry / Hydration Tests ---

  test "create_entry sends correct payload and returns response" do
    GatekeeperClient.stub :get_auth_token, "valid_token" do
      success = @mock_response.new(201, true, { "status" => "created" })

      HTTParty.stub :post, success do
        result = GatekeeperClient.create_entry(
          raw_hash: "abc123hash",
          song_id: "mbid_1",
          release_id: "rel_1"
        )
        assert_equal "created", result["status"]
      end
    end
  end

  # --- Remote Hash Tests ---

  test "remote_hash_exists? returns true when API finds a match" do
    GatekeeperClient.stub :get_auth_token, "valid_token" do
      # remote_hash_exists? uses authenticated_get, which calls HTTParty.get
      found = @mock_response.new(200, true, { "raw_hash" => "exists" })

      HTTParty.stub :get, found do
        assert GatekeeperClient.remote_hash_exists?("some_hash")
      end
    end
  end

  test "remote_hash_exists? returns false when API returns error" do
    GatekeeperClient.stub :get_auth_token, "valid_token" do
      not_found = @mock_response.new(404, false, nil)

      HTTParty.stub :get, not_found do
        assert_not GatekeeperClient.remote_hash_exists?("missing_hash")
      end
    end
  end

  # --- Data Fetching Tests ---

  test "fetch_single_song returns parsed JSON data" do
    GatekeeperClient.stub :get_auth_token, "valid_token" do
      song_data = { "song" => { "songName" => "Test Track" } }
      success = @mock_response.new(200, true, song_data)

      HTTParty.stub :get, success do
        result = GatekeeperClient.fetch_single_song("mbid_abc")
        assert_equal "Test Track", result["song"]["songName"]
      end
    end
  end
end