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

    @mock_artist_api = { "artist" => { "artistName" => "API Artist" } }

    @mock_albums_index = [{ "albumID" => @album_id }]

    @mock_album_api = {
      "album" => { "albumName" => "API Album", "coverPath" => "" }, # Blank coverPath to trigger download
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

  test "falls back to local database if Gatekeeper returns nil" do
    AlbumInfo.create!(albumID: @album_id, albumName: "Local Album", albumType: "Album")
    AlbumRelease.create!(releaseID: @release_id, albumID: @album_id)

    SongInfo.create!(
      songID: @song_id,
      songName: "Local Database Track",
      trackNumber: "1",
      releaseID: @release_id
    )

    GatekeeperClient.stub :fetch_single_song, nil do
      ui_song = SongDetailBuilder.call(@song_id)

      assert_equal "Local Database Track", ui_song.songName
    end
  end

  test "returns Unrecognized Track placeholder if both remote and local fail" do
    GatekeeperClient.stub :fetch_single_song, nil do
      ui_song = SongDetailBuilder.call("completely_missing_id")

      assert_equal "Unrecognized Track", ui_song.songName
      assert_equal "completely_missing_id", ui_song.songID
    end
  end
end