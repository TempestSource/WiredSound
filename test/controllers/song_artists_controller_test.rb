require "test_helper"

class SongArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do

    @mock_songs = [
      { "songID" => "sng_1", "songName" => "Duvet" },
      { "songID" => "sng_2", "songName" => "Twilight" }
    ]
  end

  test "should get index" do
    mock_response = OpenStruct.new(success?: true, parsed_response: @mock_songs)

    HTTParty.stub :get, mock_response do
      post api_v1_auth_login_url, params: {
        username: "lain",
        password: ENV.fetch('LAIN_PASSWORD') { 'test_password' }
      }

      get api_song_artists_url, as: :json
      assert_response :success
    end
  end
end