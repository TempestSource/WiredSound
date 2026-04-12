require "test_helper"
require "fileutils"

class SongsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = AlbumInfo.create!(albumID: "test_alb", albumName: "Test Album")
    @release = AlbumRelease.create!(releaseID: "test_rel", albumID: @album.albumID)

    @song = SongInfo.create!(songID: "test_song_1", songName: "Test_Track", releaseID: @release.releaseID)

    @library_path = Rails.root.join("storage", "library", "#{@song.songName}.mp3")

    FileUtils.mkdir_p(File.dirname(@library_path))
    FileUtils.touch(@library_path)
  end

  teardown do
    File.delete(@library_path) if File.exist?(@library_path)
  end

  test "should get index and find local file" do
    get songs_url
    assert_response :success
    assert_match @song.songName, @response.body
  end

  test "should destroy song and physical file" do
    assert File.exist?(@library_path)

    assert_difference("SongInfo.count", -1) do
      delete song_url(@song)
    end

    assert_redirected_to songs_path
    assert_equal "Successfully deleted '#{@song.songName}' from your library and storage.", flash[:notice]

    assert_not File.exist?(@library_path)
  end
end