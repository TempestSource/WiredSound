# test/services/library_builder_test.rb
require "test_helper"
require "fileutils"
require "ostruct"

class LibraryBuilderTest < ActiveSupport::TestCase
  def setup

    @library_dir = Rails.root.join('storage', 'library')
    @unrecognized_dir = Rails.root.join('storage', 'unrecognized')
    FileUtils.mkdir_p(@library_dir)
    FileUtils.mkdir_p(@unrecognized_dir)

    @test_id = "test-song-uuid-123"
    @mock_attributes = {
      "songID" => @test_id,
      "songName" => "Zebra",
      "trackNumber" => "1"
    }
  end

  def teardown
    # Clean up the physical files after tests finish
    FileUtils.rm_rf(@library_dir)
    FileUtils.rm_rf(@unrecognized_dir)
  end

  # --- Tests for fetch_and_sort_songs ---

  test "returns recognized songs from local database" do
    # Create a real physical file for the code to find
    FileUtils.touch(@library_dir.join("#{@test_id}.mp3"))

    # Mock the database lookup
    mock_song = OpenStruct.new(
      attributes: @mock_attributes,
      artist_infos: [OpenStruct.new(artistName: "Aardvark")],
      album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Animals"))
    )

    SongInfo.stub :find_by, mock_song do
      songs = LibraryBuilder.fetch_and_sort_songs
      assert_equal 1, songs.size
      assert_instance_of UiSong, songs.first
      assert_equal "Zebra", songs.first.songName
    end
  end

  test "filters songs based on search query" do
    song_a = UiSong.build_from_api({"songName" => "Apple"}, "1", [OpenStruct.new(artistName: "Fruit")])
    song_b = UiSong.build_from_api({"songName" => "Banana"}, "2", [OpenStruct.new(artistName: "Fruit")])

    LibraryBuilder.stub :fetch_and_sort_songs, [song_a, song_b] do
      results = LibraryBuilder.fetch_and_sort_songs(query: "Apple")
      assert_includes results.map(&:songName), "Apple"
    end
  end

  test "sorts songs by title, artist, or album" do
    song1 = OpenStruct.new(songName: "B", artist_infos: [OpenStruct.new(artistName: "Z")], album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "M")))
    song2 = OpenStruct.new(songName: "A", artist_infos: [OpenStruct.new(artistName: "Y")], album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "N")))
    songs = [song1, song2]

    LibraryBuilder.send(:apply_search_and_sort!, songs, nil, "title")
    assert_equal "A", songs.first.songName

    LibraryBuilder.send(:apply_search_and_sort!, songs, nil, "artist")
    assert_equal "Y", songs.first.artist_infos.first.artistName
  end

  # --- Tests for fetch_unrecognized_files ---

  test "identifies unrecognized files and provides placeholders" do
    # Create a real physical file
    FileUtils.touch(@unrecognized_dir.join("noise_sample.mp3"))

    results = LibraryBuilder.fetch_unrecognized_files

    assert_equal 1, results.size
    assert_equal "noise_sample", results.first.songName
    assert_equal "Unknown Artist", results.first.artist_infos.first.artistName
  end
end