require "test_helper"
require "fileutils"

class SongsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = AlbumInfo.create!(albumID: "test_alb", albumName: "Test Album")
    @release = AlbumRelease.create!(releaseID: "test_rel", albumID: @album.albumID)
    @song = SongInfo.create!(songID: "test_song_1", songName: "Test_Track", releaseID: @release.releaseID)

    @library_path = Rails.root.join("storage", "library", "#{@song.songID}.mp3")
    FileUtils.mkdir_p(File.dirname(@library_path))
    FileUtils.touch(@library_path)

    @mock_shallow_songs = [{ "songID" => "test_song_1" }]
    @mock_deep_song = {
      "song" => {
        "songID" => "test_song_1",
        "songName" => "Test_Track",
        "releaseID" => "test_rel"
      },
      "artists" => [{ "artistName" => "Mocked Artist" }]
    }
  end

  teardown do
    File.delete(@library_path) if File.exist?(@library_path)
  end

  test "should get index and find local file using mock API data" do
    AudioProcessor.stub :fetch_remote_songs, @mock_shallow_songs do
      AudioProcessor.stub :fetch_single_song, @mock_deep_song do
        AudioProcessor.stub :fetch_remote_artists, [] do
          AudioProcessor.stub :fetch_remote_albums, [] do
            get songs_url
          end
        end
      end
    end

    assert_response :success
    assert_match "Test_Track", @response.body
  end

  test "should destroy song and physical file" do
    assert File.exist?(@library_path)

    assert_difference("SongInfo.count", -1) do
      delete song_url(@song)
    end

    assert_redirected_to songs_path

    assert_equal "Successfully removed the song from your library and storage.", flash[:notice]

    assert_not File.exist?(@library_path)
  end
end