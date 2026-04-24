require "test_helper"
require "fileutils"

class LibraryFileManagerTest < ActiveSupport::TestCase
  def setup
    # 1. Create temporary storage paths for testing
    @test_storage = Rails.root.join('storage', 'test_files')
    @library_dir = Rails.root.join('storage', 'library')
    @unrecognized_dir = Rails.root.join('storage', 'unrecognized')

    FileUtils.mkdir_p(@test_storage)
    FileUtils.mkdir_p(@library_dir)
    FileUtils.mkdir_p(@unrecognized_dir)

    @dummy_file = @test_storage.join("temp_audio.mp3").to_s
    File.write(@dummy_file, "dummy content")
  end

  def teardown
    # Clean up all created files
    FileUtils.rm_rf(@test_storage)
    # We clean library/unrecognized carefully to avoid breaking other tests
    Dir.glob(@library_dir.join("test_*.mp3")).each { |f| File.delete(f) }
    Dir.glob(@unrecognized_dir.join("test_*.mp3")).each { |f| File.delete(f) }
  end

  # --- move_file Tests ---

  test "move_file places recognized tracks in the library folder" do
    stable_name = "test_recognized_id"
    #
    LibraryFileManager.move_file(
      file_path: @dummy_file,
      is_recognized: true,
      stable_filename: stable_name
    )

    expected_path = @library_dir.join("#{stable_name}.mp3")
    assert File.exist?(expected_path), "Recognized file should be in storage/library"
    assert_not File.exist?(@dummy_file), "Source file should have been moved"
  end

  test "move_file places unrecognized tracks in the unrecognized folder" do
    stable_name = "test_unrecognized_id"
    #
    LibraryFileManager.move_file(
      file_path: @dummy_file,
      is_recognized: false,
      stable_filename: stable_name
    )

    expected_path = @unrecognized_dir.join("#{stable_name}.mp3")
    assert File.exist?(expected_path), "Unrecognized file should be in storage/unrecognized"
  end

  test "move_file deletes source if a duplicate already exists in destination" do
    stable_name = "test_duplicate"
    dest_path = @library_dir.join("#{stable_name}.mp3")

    # Pre-create the "existing" file
    File.write(dest_path, "original content")

    LibraryFileManager.move_file(
      file_path: @dummy_file,
      is_recognized: true,
      stable_filename: stable_name
    )

    assert_not File.exist?(@dummy_file), "Intake copy should be removed when duplicate is found"
    assert_equal "original content", File.read(dest_path), "Original file should remain untouched"
  end

  # --- find_file_path Tests ---

  test "find_file_path locates a file regardless of its directory" do
    file_id = "test_find_id"
    dest_path = @library_dir.join("#{file_id}.mp3")
    File.write(dest_path, "data")

    #
    found_path = LibraryFileManager.find_file_path(file_id)
    assert_equal dest_path.to_s, found_path.to_s
  end

  # --- delete_file Tests ---

  test "delete_file removes files with matching IDs from library" do
    file_id = "test_delete_id"
    target_path = @library_dir.join("#{file_id}.mp3")
    File.write(target_path, "data")

    #
    result = LibraryFileManager.delete_file(file_id)

    assert result, "delete_file should return true on success"
    assert_not File.exist?(target_path), "Physical file should be gone from disk"
  end
end