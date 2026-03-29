require "test_helper"

class SongsControllerTest < ActionDispatch::IntegrationTest
  set_fixture_class songs: SongInfo

  test "should get index" do
    get songs_url
    assert_response :success
  end
end