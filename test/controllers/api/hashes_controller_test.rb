require "test_helper"

class Api::HashesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a song to link the hash to
    @song = SongInfo.create!(songID: "sng-uuid-123", songName: "Test Song", trackNumber: "1")

    # Create an existing hash match
    @hash_match = HashMatch.create!(
      raw_hash: "a" * 32,
      songID: @song.songID
    )

    # Mock headers for authentication
    @auth_headers = { "Authorization" => "Bearer user_token" }
    @admin_headers = { "Authorization" => "Bearer admin_token" }
  end

  # --- Public Access Tests (:index, :show) ---

  test "index should return all hashes as json" do
    get api_hashes_url, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal @hash_match.raw_hash, json.first["raw_hash"]
  end

  test "show should return specific hash match" do
    get api_hash_url(@hash_match.id), as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @hash_match.raw_hash, json["raw_hash"]
  end

  # --- Creation Test (:create) ---

  test "create should add a new hash match" do
    new_hash = "b" * 32

    # create is NOT skipped in authenticate, so it requires headers
    assert_difference("HashMatch.count", 1) do
      post api_hashes_url,
           params: { raw_hash: new_hash, songID: @song.songID },
           headers: @auth_headers,
           as: :json
    end

    assert_response :created
  end

  # --- Administrative Access (:update, :destroy) ---

  test "update should be blocked for non-admins" do
    new_song_id = "sng-uuid-999"

    # Verifies before_action :admin_page
    patch api_hash_url(@hash_match.id),
          params: { songID: new_song_id },
          headers: @auth_headers,
          as: :json

    assert_response :unauthorized
    @hash_match.reload
    assert_equal @song.songID, @hash_match.songID
  end

  test "update succeeds with admin privileges" do
    new_song_id = "sng-uuid-updated"
    # Ensure this new song exists for the update to be valid
    SongInfo.create!(songID: new_song_id, songName: "Updated Song")

    patch api_hash_url(@hash_match.id),
          params: { songID: new_song_id },
          headers: @admin_headers,
          as: :json

    assert_response :ok
    @hash_match.reload
    assert_equal new_song_id, @hash_match.songID
  end

  test "destroy removes hash match with admin privileges" do
    assert_difference("HashMatch.count", -1) do
      delete api_hash_url(@hash_match.id), headers: @admin_headers, as: :json
    end
    assert_response :success
  end

  test "destroy returns 404 for missing hash" do
    delete api_hash_url(99999), headers: @admin_headers, as: :json

    # Verifies RecordNotFound rescue in hashes_controller
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Hash not found", json["error"]
  end
end