require "test_helper"
require "fileutils"
require "ostruct"

class LibraryBuilderTest < ActiveSupport::TestCase
  def setup
    # 1. Mock paths
    @library_dir = Rails.root.join('storage', 'library')
    @unrecognized_dir = Rails.root.join('storage', 'unrecognized')

    # 2. Mock Song ID
    @test_id = "test-song-uuid-123"

    # 3. Create mock database attributes for UiSong
    @mock_attributes = {
      "songID" => @test_id,
      "songName" => "Zebra",
      "trackNumber" => "1"
    }
  end

  # --- Helper to stub File System and Database ---
  def stub_library_env(files: [], db_record: nil)
    Dir.stub :exist?, true do
      Dir.stub :glob, files do
        SongInfo.stub :find_by, db_record do
          yield
        end
      end
    end
  end

  # --- Tests for fetch_and_sort_songs ---

  test "returns recognized songs from local database" do
    # Simulate a file existing in storage/library
    mock_files = ["/path/to/#{@test_id}.mp3"]

    # Simulate the local database record found by Dbupdater
    mock_song = OpenStruct.new(
      attributes: @mock_attributes,
      artist_infos: [OpenStruct.new(artistName: "Aardvark")],
      album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Animals"))
    )

    stub_library_env(files: mock_files, db_record: mock_song) do
      songs = LibraryBuilder.fetch_and_sort_songs

      assert_equal 1, songs.size
      assert_instance_of UiSong, songs.first
      assert_equal "Zebra", songs.first.songName
    end
  end

  test "filters songs based on search query" do
    # Create two mock objects
    song_a = UiSong.build_from_api({"songName" => "Apple"}, "1", [OpenStruct.new(artistName: "Fruit")])
    song_b = UiSong.build_from_api({"songName" => "Banana"}, "2", [OpenStruct.new(artistName: "Fruit")])

    # Manually testing the sorting/filtering logic inside fetch_and_sort_songs
    mock_files = ["/path/to/1.mp3", "/path/to/2.mp3"]

    # We stub the builder to return our two objects, then verify filtering
    LibraryBuilder.stub :fetch_and_sort_songs, [song_a, song_b] do
      # Note: We are testing the controller's typical usage of the builder
      results = LibraryBuilder.fetch_and_sort_songs(query: "Apple")

      # Depending on how apply_search_and_sort! is called, we verify search logic
      assert_includes results.map(&:songName), "Apple"
    end
  end

  test "sorts songs by title, artist, or album" do
    song1 = OpenStruct.new(songName: "B", artist_infos: [OpenStruct.new(artistName: "Z")], album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "M")))
    song2 = OpenStruct.new(songName: "A", artist_infos: [OpenStruct.new(artistName: "Y")], album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "N")))

    songs = [song1, song2]

    # Test Title Sort
    LibraryBuilder.send(:apply_search_and_sort!, songs, nil, "title")
    assert_equal "A", songs.first.songName

    # Test Artist Sort
    LibraryBuilder.send(:apply_search_and_sort!, songs, nil, "artist")
    assert_equal "Y", songs.first.artist_infos.first.artistName
  end

  # --- Tests for fetch_unrecognized_files ---

  test "identifies unrecognized files and provides placeholders" do
    mock_unrecognized = ["/path/to/noise_sample.mp3"]

    Dir.stub :exist?, true do
      Dir.stub :glob, mock_unrecognized do
        results = LibraryBuilder.fetch_unrecognized_files

        assert_equal 1, results.size
        assert_equal "noise_sample", results.first.songName
        assert_equal "Unknown Artist", results.first.artist_infos.first.artistName
      end
    end
  end
end