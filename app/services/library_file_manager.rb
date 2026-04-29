# app/services/library_file_manager.rb
require 'fileutils'

class LibraryFileManager
  # We use keyword arguments (name: value) so it's impossible to pass the wrong data in the wrong order
  def self.move_file(file_path:, is_recognized:, stable_filename:)
    # 1. Determine the target folder
    target_folder = is_recognized ? "library" : "unrecognized"
    final_dir = Rails.root.join("storage", target_folder)

    # 2. Ensure the directory actually exists before trying to move anything into it
    FileUtils.mkdir_p(final_dir)
    extension = File.extname(file_path)
    destination_path = final_dir.join("#{stable_filename}#{extension}")

    if File.exist?(destination_path)
      puts "Duplicate found at #{destination_path}. Removing intake copy."
      FileUtils.rm(file_path) if File.exist?(file_path)
    elsif File.exist?(file_path)
      FileUtils.mv(file_path, destination_path)
    end

    # Return the path relative to the Rails root
    "storage/#{target_folder}/#{stable_filename}#{extension}"
  end

  def self.delete_file(file_id)
    files_deleted = false
    target_dirs = [
      Rails.root.join("storage", "library"),
      Rails.root.join("storage", "unrecognized")
    ]

    target_dirs.each do |dir|
      next unless Dir.exist?(dir)

      # FIX: Use children to safely find the file matching the ID
      files_to_delete = dir.children.select do |f|
        f.file? && f.basename(".*").to_s == file_id.to_s
      end

      files_to_delete.each do |file|
        File.delete(file)
        files_deleted = true
        puts "Deleted physical file: #{file}"
      end
    end

    files_deleted
  end

  def self.find_file_path(file_id)
    target_dirs = [
      Rails.root.join("storage", "library"),
      Rails.root.join("storage", "unrecognized")
    ]

    target_dirs.each do |dir|
      next unless Dir.exist?(dir)

      # FIX: Use children to safely find the file path
      matches = dir.children.select do |f|
        f.file? && f.basename(".*").to_s == file_id.to_s
      end

      return matches.first.to_s if matches.any?
    end

    nil
  end
end