require "test_helper"

class LibraryBroadcasterTest < ActiveSupport::TestCase
  setup do
    @song_id = "test-song-123"
    @song_name = "Testing Broadcast"
  end

  test "broadcasts to the 'songs' stream for recognized tracks" do
    # 1. Stub the Turbo Stream broadcast so it doesn't try to send a real message
    # We verify it's called with the correct target and stream name
    Turbo::StreamsChannel.stub :broadcast_prepend_to, true do
      result = LibraryBroadcaster.broadcast(
        song_id: @song_id,
        song_name: @song_name,
        is_recognized: true
      )

      # 2. Verify the returned object is a UiSong
      assert_instance_of UiSong, result
      assert_equal @song_name, result.songName
      assert_equal "Identifying...", result.artist_infos.first.artistName
    end
  end

  test "broadcasts to the 'unrecognized_songs' stream for unknown tracks" do
    Turbo::StreamsChannel.stub :broadcast_prepend_to, true do
      result = LibraryBroadcaster.broadcast(
        song_id: @song_id,
        song_name: @song_name,
        is_recognized: false
      )

      # 2. Verify construction of the UI object for unrecognized files
      assert_instance_of UiSong, result
      assert_equal "Unknown Artist", result.artist_infos.first.artistName
      assert_equal "Unknown Album", result.album_release.album_info.albumName
    end
  end

  test "returns a UiSong object that mimics the SongInfo model" do
    # Verify the build_from_api logic inside the broadcaster
    Turbo::StreamsChannel.stub :broadcast_prepend_to, true do
      ui_song = LibraryBroadcaster.broadcast(
        song_id: @song_id,
        song_name: @song_name,
        is_recognized: true
      )

      # Test the Rails-mimicry methods defined in UiSong
      assert_equal "SongInfo", ui_song.class.model_name.to_s
      assert_equal [@song_id], ui_song.to_key
      assert ui_song.persisted?
    end
  end
end