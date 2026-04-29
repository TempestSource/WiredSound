# frozen_string_literal: true

namespace :audio do
  def find_storage_root
    base_path = SystemSetting.find_by(key: 'incoming_path')&.value

    if base_path.present?
      Pathname.new(base_path).dirname
    else
      Rails.root.join('storage')
    end
  end

  desc "Moves all files from library back to incoming for reprocessing"
  task reprocess_library: :environment do
    require 'fileutils'

    storage_root = find_storage_root
    library_dir = storage_root.join('library')
    incoming_dir = storage_root.join('incoming_music')


    FileUtils.mkdir_p(library_dir)
    FileUtils.mkdir_p(incoming_dir)

    files_to_move = Dir.glob(File.join(library_dir, '*'))

    if files_to_move.empty?
      puts "The library folder at #{library_dir} is already empty."
      next
    end

    puts "Moving #{files_to_move.count} files back to incoming..."

    files_to_move.each do |file|
      next if File.directory?(file)
      filename = File.basename(file)
      destination = incoming_dir.join(filename)


      FileUtils.mv(file, destination)
      puts "  Moved: #{filename}"
    end
    puts "Successfully moved all files to #{incoming_dir}!"
  end

  desc "Retry processing unrecognized audio files"
  task retry_unrecognized: :environment do
    require 'fileutils'

    storage_root = find_storage_root
    unrecognized_dir = storage_root.join('unrecognized')
    incoming_dir = storage_root.join('incoming_music')

    FileUtils.mkdir_p(unrecognized_dir)
    FileUtils.mkdir_p(incoming_dir)

    files = Dir.glob(unrecognized_dir.join('*.{mp3,wav,flac,m4a}'))

    if files.empty?
      puts "No unrecognized files found in #{unrecognized_dir}!"
      next
    end

    files.each do |file_path|
      filename = File.basename(file_path)
      file_hash = AudioHasher.call(file_path)

      match_record = HashMatch.find_by(raw_hash: file_hash)

      if match_record
        song_id = match_record.songID
        song = SongInfo.find_by(songID: song_id)

        SongArtist.where(songID: song_id).destroy_all
        song.destroy if song

        match_record.destroy
      end

      destination = incoming_dir.join(filename)
      FileUtils.mv(file_path, destination)
      puts "Re-queued: #{filename}"
    end

    puts "Successfully re-queued #{files.count} files for processing!"
  end
end