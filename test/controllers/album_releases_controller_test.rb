require "test_helper"

class AlbumReleasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = AlbumInfo.create!(albumID: "alb_rel_test", albumName: "Parent Album")
    @release = AlbumRelease.create!(
      releaseID: "rel_test_456",
      albumID: @album.albumID,
      releaseName: "Test Release"
    )
  end

  test "should get index json" do
    get album_releases_url
    assert_response :success
  end

  test "should show release json" do
    get album_release_url(@release)
    assert_response :success
  end
end