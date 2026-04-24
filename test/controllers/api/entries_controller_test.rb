require "test_helper"

class Api::EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @valid_hash = "a" * 32
    @song_id = "sng-uuid-123"
    @release_id = "rel-uuid-456"
    @album_id = "alb-uuid-789"

    # 1. Create a User for authentication
    @user = User.create!(
      username: "lain",
      password: "password_secure_123",
      password_confirmation: "password_secure_123",
      role: "user" # entries_controller doesn't require admin, just a user
    )

    # 2. Create the dependency chain: Album -> Release
    @album = AlbumInfo.create!(
      albumID: @album_id,
      albumName: "Test Album",
      albumType: "Album"
    )

    @release = AlbumRelease.create!(
      releaseID: @release_id,
      albumID: @album_id
    )

    # 3. Create the Song (Validation will now pass!)
    @song = SongInfo.create!(
      songID: @song_id,
      songName: "Test Song",
      trackNumber: "1",
      releaseID: @release_id
    )

    # Mocking the authenticated user headers
    @auth_headers = { "Authorization" => "Bearer stubbed_token" }
  end

  # --- Validation Tests ---

  test "create should return bad request if parameters are missing" do
    # FIX: Include both 'id' and 'user_id' using the username primary key
    mock_payload = [
      { "id" => @user.username, "user_id" => @user.username, "role" => "user" },
      { "alg" => "HS256" }
    ]

    JWT.stub :decode, mock_payload do
      post api_entries_url,
           params: { raw_hash: @valid_hash },
           headers: @auth_headers,
           as: :json
    end

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Requires raw_hash, songID and releaseID", json["error"]
  end

  test "create should call Dbupdater and return song info on success" do
    # FIX: Same payload update here to bypass the 'Invalid user' check
    mock_payload = [
      { "id" => @user.username, "user_id" => @user.username, "role" => "user" },
      { "alg" => "HS256" }
    ]

    JWT.stub :decode, mock_payload do
      Dbupdater.stub :db_add, true do
        post api_entries_url,
             params: { raw_hash: @valid_hash, songID: @song_id, releaseID: @release_id },
             headers: @auth_headers,
             as: :json

        assert_response :ok
        json = JSON.parse(response.body)
        assert_equal @song_id, json["songID"]
        assert_equal "Test Song", json["songName"]
      end
    end
  end

  test "create should be unauthorized without valid token" do
    # This test purposefully does NOT stub JWT to verify security
    post api_entries_url,
         params: { raw_hash: @valid_hash, songID: @song_id, releaseID: @release_id },
         as: :json

    assert_response :unauthorized
  end
end