require "test_helper"

class Api::ArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # 1. FIX: Ensure the user is created as an admin in the database
    @user = User.create!(
      username: "lain",
      password: "password_secure_123",
      password_confirmation: "password_secure_123",
    )

    @artist = ArtistInfo.create!(artistID: "art-uuid-123", artistName: "PinocchioP", artistType: "Person", artistCountry: "JP")
    @album = AlbumInfo.create!(albumID: "alb-1", albumName: "Test Album", albumType: "Album")
    @release = AlbumRelease.create!(releaseID: "rel-1", albumID: @album.albumID)
    @song = SongInfo.create!(songID: "sng-1", songName: "Test Song", trackNumber: "1", releaseID: @release.releaseID)

    @album_link = AlbumArtist.create!(artistID: @artist.artistID, albumID: @album.albumID)
    @song_link = SongArtist.create!(artistID: @artist.artistID, songID: @song.songID)
  end

  # --- Public Actions ---

  test "index should return all artists as json" do
    get api_artists_url, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal @artist.artistName, json.first["artistName"]
  end

  test "show should return specific artist details" do
    get api_artist_url(@artist.artistID), as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "PinocchioP", json["artistName"]
  end

  test "show should return 404 for missing artist" do
    get api_artist_url("missing-uuid"), as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Artist not found", json["error"]
  end

  # --- Protected Actions (Admin Required) ---

  test "update should be blocked for non-admins" do
    patch api_artist_url(@artist.artistID),
          params: { artistName: "New Name" },
          as: :json

    # Verifies the before_action :admin_page is active
    assert_response :unauthorized
    @artist.reload
    assert_equal "PinocchioP", @artist.artistName
  end
end