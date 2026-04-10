require "test_helper"

class SongArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    art = ArtistInfo.create!(artistID: "art_junction", artistName: "Junction Artist")
    alb = AlbumInfo.create!(albumID: "alb_junction", albumName: "Junction Album")
    rel = AlbumRelease.create!(releaseID: "rel_junction", albumID: alb.albumID)
    sng = SongInfo.create!(songID: "sng_junction", songName: "Junction Song", releaseID: rel.releaseID)

    @song_artist = SongArtist.create!(songID: sng.songID, artistID: art.artistID)
  end

  test "should get index" do
    get song_artists_url
    assert_response :success
  end
end