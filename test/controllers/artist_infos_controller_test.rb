require "test_helper"

class ArtistInfosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @artist = ArtistInfo.create!(
      artistID: "art_test_99",
      artistName: "Test Artist"
    )
  end

  test "should get index json" do
    get api_artists_url
    assert_response :success
    assert_equal "application/json", @response.media_type
  end

  test "should show artist json" do
    get api_artist_url(@artist)
    assert_response :success
  end
end