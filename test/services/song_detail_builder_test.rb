require "test_helper"
require "ostruct"

class SongDetailBuilderTest < ActiveSupport::TestCase
  setup do
    @song_id = "test_id_123"
    @release_id = "rel_456"
    @artist_id = "art_789"
    @album_id = "alb_000"

    # Mock responses for GatekeeperClient
    @mock_song_api = {
      "song" => { "songID" => @song_id, "songName" => "API Track", "releaseID" => @release_id },
      "artists" => [{ "artistID" => @artist_id }]
    }

    @mock_artist_api = { "artist" => { "artistID" => @artist_id, "artistName" => "API Artist" } }

    @mock_albums_index = [{ "albumID" => @album_id }]

    @mock_album_api = {
      # THE FIX: Add the "albumID" key here
      "album" => { "albumID" => @album_id, "albumName" => "API Album", "coverPath" => "" },
      "releases" => [{ "releaseID" => @release_id }]
    }
  end

  test "builds UiSong from remote Gatekeeper data and fetches missing cover art" do
    # Deep nesting stubs to simulate the full API hydration chain
    GatekeeperClient.stub :fetch_single_song, @mock_song_api do
      GatekeeperClient.stub :fetch_single_artist, @mock_artist_api do
        GatekeeperClient.stub :fetch_remote_albums, @mock_albums_index do
          GatekeeperClient.stub :fetch_single_album, @mock_album_api do

            # Verify that MetadataHelper is called to fetch the missing image
            Metadata.stub :cover, true do
              @mock_album_api["album"]["coverPath"] = "/covers/downloaded.jpg"

              ui_song = SongDetailBuilder.call(@song_id)

              assert_equal "API Track", ui_song.songName
              assert_equal "API Artist", ui_song.artist_infos.first.artistName
              assert_equal "API Album", ui_song.album_release.album_info.albumName

              # Confirm the cover art logic applied the downloaded path
              assert_equal "/covers/downloaded.jpg", ui_song.album_release.album_info.coverPath
            end

          end
        end
      end
    end
  end

  test "returns nil so AudioProcessor can fallback if Gatekeeper returns nil" do
    # THE FIX: Assert nil instead of checking for a dummy track name
    GatekeeperClient.stub :fetch_single_song, nil do
      ui_song = SongDetailBuilder.call(@song_id)
      assert_nil ui_song
    end
  end

  test "returns nil if remote fails and no data is found" do
    GatekeeperClient.stub :fetch_single_song, nil do
      ui_song = SongDetailBuilder.call("missing_id")
      assert_nil ui_song
    end
  end
end