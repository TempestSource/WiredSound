require "test_helper"
require "ostruct"

class SongsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @song_id = "test_song_1"

    # 1. Create the local database record required for deletion tests
    @song = SongInfo.create!(
      songID: @song_id,
      songName: "Test_Track",
      releaseID: "test_rel"
    )

    # 2. Mock a UiSong object that the LibraryBuilder and Controller use to render the views
    @mock_ui_song = UiSong.new(
      songID: @song_id,
      songName: "Test_Track",
      artist_infos: [OpenStruct.new(artistName: "Mocked Artist")],
      album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Test Album", coverPath: nil))
    )
  end

  test "should get index using LibraryBuilder" do
    LibraryBuilder.stub :fetch_and_sort_songs, [@mock_ui_song] do
      LibraryBuilder.stub :fetch_unrecognized_files, [] do
        get songs_url
      end
    end

    assert_response :success
    assert_match "Test_Track", @response.body
  end

  test "should get show using SongDetailBuilder" do
    # UPGRADE: We now stub the Service Object instead of the API client!
    SongDetailBuilder.stub :call, @mock_ui_song do
      get song_url(@song)
    end

    assert_response :success
    assert_match "Test_Track", @response.body
  end

  test "should destroy song and trigger LibraryFileManager" do
    LibraryFileManager.stub :delete_file, true do
      assert_difference("SongInfo.count", -1) do
        delete song_url(@song)
      end
    end

    assert_redirected_to songs_path
    assert_equal "Successfully removed the song from your library and storage.", flash[:notice]
  end
end