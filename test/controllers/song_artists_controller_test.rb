require "test_helper"

class SongArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do

    @mock_songs = [
      { "songID" => "sng_1", "songName" => "Duvet" },
      { "songID" => "sng_2", "songName" => "Twilight" }
    ]
  end

  test "should get index" do
    # Mock the API response so we don't need a real server on GitHub
    mock_response = OpenStruct.new(success?: true, parsed_response: [{ "songName" => "Test Song" }])

    HTTParty.stub :get, mock_response do
      # We use the namespaced URL helper
      get api_song_artists_url, as: :json
      assert_response :success
    end
  end
end