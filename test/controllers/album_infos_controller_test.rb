require "test_helper"

class AlbumInfosControllerTest < ActionDispatch::IntegrationTest
  fixtures :album_infos

  setup do
    @album_info = album_infos(:one)
  end

  test "should get index and return json" do
    get album_infos_url
    assert_response :success
  end

  test "should show album info and return json" do
    get album_info_url(@album_info)
    assert_response :success
  end
end