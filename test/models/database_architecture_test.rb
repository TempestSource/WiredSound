require "test_helper"

class DatabaseArchitectureTest < ActiveSupport::TestCase
  test "comprehensive database relationships and cascade deletion" do

    album = AlbumInfo.create!(albumID: "alb_test_full", albumName: "Full Architecture Album")
    artist = ArtistInfo.create!(artistID: "art_test_full", artistName: "Full Architecture Artist")

    song = SongInfo.create!(songID: "sng_test_full", songName: "Full Architecture Song", album_info: album)


    song.artist_infos << artist

    album.artist_infos << artist

    release = AlbumRelease.create!(releaseID: "rel_test_full", album_info: album)

    HashMatch.save_hash("test_hash_signature_xyz", song.songID)


    assert_includes song.artist_infos, artist, "Song should be linked to the Artist"
    assert_includes album.artist_infos, artist, "Album should be linked to the Artist"

    assert_includes artist.song_infos, song, "Artist should have the Song"
    assert_includes artist.album_infos, album, "Artist should have the Album"

    assert_equal album, song.album_info, "Song should belong to the Album"
    assert_equal album, release.album_info, "Release should belong to the Album"
    assert_equal 1, HashMatch.where(songID: song.songID).count, "Hash signature should be saved and linked"


    album.destroy!

    assert_nil AlbumInfo.find_by(albumID: "alb_test_full"), "Album should be deleted"
    assert_nil SongInfo.find_by(songID: "sng_test_full"), "Song should be deleted via cascade"
    assert_nil AlbumRelease.find_by(releaseID: "rel_test_full"), "Release should be deleted via cascade"

    assert_equal 0, HashMatch.where(songID: "sng_test_full").count, "Hashes should be deleted via song cascade"
    assert_equal 0, SongArtist.where(songID: "sng_test_full").count, "Song-Artist links should be deleted"
    assert_equal 0, AlbumArtist.where(albumID: "alb_test_full").count, "Album-Artist links should be deleted"

    assert_not_nil ArtistInfo.find_by(artistID: "art_test_full"), "Artist should remain untouched in the database"
  end
end