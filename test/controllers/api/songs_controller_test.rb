require "test_helper"

class Api::SongsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # 1. Create the Admin User for protected routes
    @user = User.create!(
      username: "lain",
      password: "password_secure_123",
      password_confirmation: "password_secure_123",
      role: "admin"
    )

    # 2. Create the dependency chain: Album -> Release
    @album = AlbumInfo.create!(
      albumID: "alb-uuid-456",
      albumName: "Test Album",
      albumType: "Album"
    )

    @release = AlbumRelease.create!(
      releaseID: "rel-uuid-456",
      albumID: @album.albumID
    )

    # 3. Create a test song (now it has a valid release to point to!)
    @song = SongInfo.create!(
      songID: "sng-uuid-123",
      songName: "Hurt2",
      trackNumber: "1",
      releaseID: @release.releaseID
    )

    # 4. Create an associated artist link
    @artist = ArtistInfo.create!(artistID: "art-uuid-789", artistName: "PinocchioP", artistType: "Person")
    @artist_link = SongArtist.create!(
      songID: @song.songID,
      artistID: @artist.artistID
    )

    # Mock headers for authentication
    @auth_headers = { "Authorization" => "Bearer user_token" }
    @admin_headers = { "Authorization" => "Bearer stubbed_token" }
  end

  # --- Public Access Tests (:index, :show) ---

  test "index should return all songs as json" do
    get api_songs_url, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal @song.songName, json.first["songName"]
  end

  test "show should return song details and associated artists" do
    get api_song_url(@song.id), as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "Hurt2", json["song"]["songName"]
    assert_not_empty json["artists"]
    assert_equal @artist_link.artistID, json["artists"].first["artistID"]
  end

  test "show should return 404 for non-existent song" do
    get api_song_url("missing-id"), as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Song not found", json["error"]
  end

  # --- Protected Access Tests (:update, :destroy) ---

  test "update should be blocked for non-admins" do
    patch api_song_url(@song.id),
          params: { songName: "New Title" },
          headers: @auth_headers,
          as: :json

    assert_response :unauthorized
    @song.reload
    assert_equal "Hurt2", @song.songName
  end

  # test "update succeeds with admin privileges" do
  #   # FIX: Add the mocked JWT payload to bypass the auth filter
  #   mock_payload = [{"user_id" => @user.id, "role" => "admin"}, {"alg" => "HS256"}]
  #
  #   JWT.stub :decode, mock_payload do
  #     patch api_song_url(@song.id),
  #           params: { songName: "Updated Title" },
  #           headers: @admin_headers,
  #           as: :json
  #   end
  #
  #   assert_response :ok
  #   @song.reload
  #   assert_equal "Updated Title", @song.songName
  # end
  #
  # test "destroy removes song and associated artist links" do
  #   # FIX: Add the mocked JWT payload here as well
  #   mock_payload = [{"user_id" => @user.id, "role" => "admin"}, {"alg" => "HS256"}]
  #
  #   JWT.stub :decode, mock_payload do
  #     assert_difference("SongInfo.count", -1) do
  #       assert_difference("SongArtist.count", -1) do
  #         delete api_song_url(@song.id), headers: @admin_headers, as: :json
  #       end
  #     end
  #   end
  #
  #   assert_response :success
  # end
end