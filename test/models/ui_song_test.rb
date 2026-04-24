require "test_helper"
require "ostruct"

class UiSongTest < ActiveSupport::TestCase
  def setup
    @song_id = "test-uuid-123"
    @raw_api_data = {
      "songID" => @song_id,
      "songName" => "Magical Girl and Chocolate",
      "trackNumber" => "5"
    }
  end

  # --- Rails Compatibility Tests ---

  test "mimics SongInfo model for Rails routing and rendering" do
    ui_song = UiSong.new(songID: @song_id)

    # Verifies that <%= render @song %> looks for songs/_song.html.erb
    assert_equal "SongInfo", ui_song.class.model_name.to_s
    # Verifies dom_id(song) generates "song_info_test-uuid-123"
    assert_equal [@song_id], ui_song.to_key
    assert_equal @test_id, ui_song.to_param
    assert ui_song.persisted?
  end

  # --- Factory Method Tests (build_from_api) ---

  test "build_from_api handles raw API hash data" do
    artists = [{ "artistName" => "PinocchioP" }]
    album = { "albumName" => "META", "coverPath" => "/covers/1.jpg" }

    ui_song = UiSong.build_from_api(@raw_api_data, @song_id, artists, album)

    assert_equal "Magical Girl and Chocolate", ui_song.songName
    assert_equal "PinocchioP", ui_song.artist_infos.first.artistName
    assert_equal "META", ui_song.album_release.album_info.albumName
  end

  test "build_from_api transforms snake_case DB attributes to camelCase UI keys" do
    # Simulate a local database record attributes (snake_case)
    db_attributes = {
      "song_id" => @song_id,
      "song_name" => "Snake Case Song",
      "track_number" => "10"
    }

    # Mock ActiveRecord objects for artist and album
    mock_artist = OpenStruct.new(attributes: { "artist_name" => "Local Artist" })
    mock_album = OpenStruct.new(attributes: { "album_name" => "Local Album", "cover_path" => "local.jpg" })

    ui_song = UiSong.build_from_api(db_attributes, @song_id, [mock_artist], mock_album)

    # Verify keys were transformed by the internal prepare_hash lambda
    assert_equal "Snake Case Song", ui_song.songName
    assert_equal "Local Artist", ui_song.artist_infos.first.artistName
    assert_equal "local.jpg", ui_song.album_release.album_info.coverPath
  end

  test "provides fallback defaults for missing track or album data" do
    # Call with minimal data
    ui_song = UiSong.build_from_api({ "songID" => @song_id }, @song_id)

    assert_equal "N/A", ui_song.trackNumber
    assert_equal "Unknown Album", ui_song.album_release.album_info.albumName
    assert_empty ui_song.artist_infos
  end
end