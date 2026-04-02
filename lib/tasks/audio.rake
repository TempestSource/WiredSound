# frozen_string_literal: true

namespace :audio do
  desc "Moves all files from storage/library back to storage/incoming_music for reprocessing"
  task reprocess_library: :environment do
    require 'fileutils'

    library_dir = Rails.root.join('storage', 'library')
    incoming_dir = Rails.root.join('storage', 'incoming_music')

    FileUtils.mkdir_p(incoming_dir)

    files_to_move = Dir.glob(File.join(library_dir, '*'))

    if files_to_move.empty?
      puts "The library folder is already empty."
      next
    end

    puts "Moving #{files_to_move.count} files from library back to incoming_music..."

    files_to_move.each do |file|
      next if File.directory?(file)

      filename = File.basename(file)
      destination = File.join(incoming_dir, filename)

      FileUtils.mv(file, destination)
      puts "  Moved: #{filename}"
    end

    puts "Successfully moved all files!"
    puts "Don't forget to truncate database before starting the listener!"
  end

  desc "Retry processing unrecognized audio files"
  task retry_unrecognized: :environment do
    require 'fileutils'

    unrecognized_dir = Rails.root.join('storage', 'unrecognized')
    incoming_dir = Rails.root.join('storage', 'incoming_music')
    FileUtils.mkdir_p(incoming_dir)

    files = Dir.glob(unrecognized_dir.join('*.{mp3,wav,flac,m4a}'))

    if files.empty?
      puts "No unrecognized files found!"
      next
    end

    puts "Found #{files.count} unrecognized files. Preparing for retry..."

    files.each do |file_path|
      filename = File.basename(file_path)

      file_hash = AudioHasher.call(file_path)

      match_record = ActiveRecord::Base.connection.execute(
        "SELECT songID FROM hash_match WHERE hash = '#{file_hash}' LIMIT 1"
      ).first

      if match_record
        song_id = match_record.first
        song = SongInfo.find_by(songID: song_id)

        SongArtist.where(songID: song_id).destroy_all
        song.destroy if song

        ActiveRecord::Base.connection.execute("DELETE FROM hash_match WHERE hash = '#{file_hash}'")
        puts "Cleared old database records for: #{filename}"
      end

      temp_path = incoming_dir.join(filename).to_s
      FileUtils.mv(file_path, temp_path)

      puts "Reprocessing: #{filename}"
      AudioProcessor.call(temp_path)
    end

    puts "\nRetry sweep complete!"
  end
end