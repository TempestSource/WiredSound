require "test_helper"

class HashMatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    alb = AlbumInfo.create!(albumID: "alb_h", albumName: "H")
    rel = AlbumRelease.create!(releaseID: "rel_h", albumID: alb.albumID)
    sng = SongInfo.create!(songID: "sng_h", songName: "H", releaseID: rel.releaseID)

    @hash_match = HashMatch.create!(
      raw_hash: "1234567890abcdef1234567890abcdef",
      songID: sng.songID
    )
  end

  test "should get index json" do
    get api_hashes_url
    assert_response :success
  end
end