require "test_helper"

class DatabaseArchitectureTest < ActiveSupport::TestCase
  test "comprehensive database relationships and cascade deletion" do
    album = AlbumInfo.create!(albumID: "alb_test_full", albumName: "Full Architecture Album", coverPath: "/covers/test.jpg")
    artist = ArtistInfo.create!(artistID: "art_test_full", artistName: "Full Architecture Artist")

    release = AlbumRelease.create!(releaseID: "rel_test_full", albumID: album.albumID)
    song = SongInfo.create!(songID: "sng_test_full", songName: "Full Architecture Song", releaseID: release.releaseID, trackNumber: 4)

    song.artist_infos << artist
    album.artist_infos << artist

    HashMatch.create!(raw_hash: "1234567890abcdef1234567890abcdef", songID: song.songID)

    assert_equal "/covers/test.jpg", album.coverPath
    assert_equal 4, song.trackNumber

    assert_includes song.artist_infos, artist, "Song should be linked to the Artist"
    assert_includes album.artist_infos, artist, "Album should be linked to the Artist"
    assert_equal release, song.album_release, "Song should belong to the Release"

    album.destroy!

    assert_nil AlbumInfo.find_by(albumID: "alb_test_full"), "Album should be deleted"
    assert_nil AlbumRelease.find_by(releaseID: "rel_test_full"), "Release should be deleted via cascade"
    assert_nil SongInfo.find_by(songID: "sng_test_full"), "Song should be deleted via cascade"

    assert_equal 0, HashMatch.where(songID: "sng_test_full").count, "Hashes should be deleted via song cascade"
    assert_equal 0, SongArtist.where(songID: "sng_test_full").count, "Song-Artist links should be deleted"

    assert_not_nil ArtistInfo.find_by(artistID: "art_test_full"), "Artist should remain untouched in the database"
  end
end