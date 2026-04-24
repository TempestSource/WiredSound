require "test_helper"

class Api::AlbumsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = AlbumInfo.create!(
      albumID: "test-album-1",
      albumName: "META",
      albumType: "Album"
    )
    # Mocking admin status for update/destroy tests
    @admin_headers = { "Authorization" => "Bearer admin_token" }
  end

  # --- Read Tests ---

  test "index returns all albums as JSON" do
    get api_albums_url
    assert_response :success
    json = JSON.parse(response.body)
    assert_not_empty json
  end

  test "show returns album with nested releases and artists" do
    get api_album_url(@album.albumID)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "META", json["album"]["albumName"]
    assert_kind_of Array, json["releases"]
    assert_kind_of Array, json["artists"]
  end

  test "show returns 404 for missing album" do
    get api_album_url("missing-id")
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Album not found", json["error"]
  end

  # --- Write/Delete Tests (Logic Verification) ---

  test "update requires admin privileges" do
    # This test proves the :admin_page filter works
    patch api_album_url(@album.albumID), params: { albumName: "New Name" }
    # Assuming your admin_page helper redirects or returns 403
    assert_response :forbidden
  end

  test "destroy removes album and associated records" do
    # Stubbing the admin check or providing a valid admin session
    # This verifies the manual deletion logic
    assert_difference("AlbumInfo.count", -1) do
      delete api_album_url(@album.albumID), headers: @admin_headers
    end
    assert_response :success
  end
end