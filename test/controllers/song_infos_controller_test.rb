require "test_helper"

class SongInfosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = AlbumInfo.create!(albumID: "alb_song_test", albumName: "Test Album")
    @release = AlbumRelease.create!(releaseID: "rel_song_test", albumID: @album.albumID)
    @song = SongInfo.create!(
      songID: "sng_test_123",
      songName: "Test Track",
      releaseID: @release.releaseID
    )
  end

  test "should get index json" do
    get song_infos_url
    assert_response :success
    assert_equal "application/json", @response.media_type
  end

  test "should show song json" do
    get song_info_url(@song)
    assert_response :success
  end
end