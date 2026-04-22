require 'set'

module Watcher
  class AudioListener
    @polling_thread = nil
    @active = false

    # 1. The Lock: A Set to remember which files are actively being processed
    @processing = Set.new

    def self.start(watch_directory = nil)
      watch_directory ||= Rails.root.join("storage", "incoming_music").to_s
      FileUtils.mkdir_p(watch_directory)

      stop

      puts "WiredSound Listener started!"
      puts "Watching for new audio files in: #{watch_directory}"

      @active = true
      @polling_thread = Thread.new do
        loop do
          break unless @active

          Rails.application.executor.wrap do
            process_existing_files(watch_directory)
          end

          sleep 2
        end
      end
    end

    def self.process_existing_files(directory)
      Dir.glob(File.join(directory, "**", "*")).each do |file_path|
        next if File.directory?(file_path)

        # 2. Check the Lock: Skip this file if another thread is already handling it
        next if @processing.include?(file_path)

        begin
          # 3. The Debounce: Ensure the file hasn't been modified in the last 2 seconds.
          # This guarantees the OS is completely done downloading/copying it.
          next if File.mtime(file_path) > 2.seconds.ago
        rescue Errno::ENOENT
          # Catch the edge case where the file was deleted right as we checked it
          next
        end

        handle_file(file_path)
      end
    end

    def self.stop
      @active = false
      if @polling_thread
        puts "Stopping active listener..."
        @polling_thread.kill
        @polling_thread = nil
      end
      @processing.clear
    end

    def self.handle_file(file_path)
      if file_path.end_with?(':Zone.Identifier')
        FileUtils.rm(file_path) rescue nil
        return
      end

      return unless file_path.match?(/\.(mp3|wav|flac|m4a)$/i)

      # Lock the file so no other loop/thread touches it
      @processing.add(file_path)

      puts "\n New file detected: #{File.basename(file_path)}"

      begin
        AudioProcessor.call(file_path)
      rescue => e
        puts "ERROR processing #{File.basename(file_path)}: #{e.message}"
      ensure
        # Unlock the file when finished (even if it errors out)
        @processing.delete(file_path)
      end
    end

    def self.restart(new_path)
      stop
      start(new_path)
      puts "WiredSound Listener re-started at: #{new_path}"
    end
  end
end