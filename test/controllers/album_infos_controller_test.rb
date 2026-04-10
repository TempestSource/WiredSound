require "test_helper"

class AlbumInfosControllerTest < ActionDispatch::IntegrationTest
  setup do
    # This assumes you have some sample data in test/fixtures/album_infos.yml
    # If not, you can create a record right here:
    # @album_info = AlbumInfo.create!(albumID: "test_123", albumName: "Test Album")
    @album_info = album_infos(:one)
  end

  test "should get index and return json" do
    get album_infos_url
    assert_response :success
    assert_equal "application/json", @response.media_type
  end

  test "should show album info and return json" do
    get album_info_url(@album_info)
    assert_response :success
    assert_equal "application/json", @response.media_type
  end
end