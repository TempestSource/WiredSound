require "listen"

module Watcher
  class AudioListener
    @active_listener = nil

    def self.start(watch_directory = nil)
      watch_directory ||= Rails.root.join("storage", "incoming_music").to_s
      FileUtils.mkdir_p(watch_directory)

      process_existing_files(watch_directory)

      puts "WiredSound Listener started!"
      puts "Watching for new audio files in: #{watch_directory}"

      @active_listener = Listen.to(watch_directory, force_polling: true, interval: 1) do |modified, added, removed|
        added.each do |file_path|
          if file_path.end_with?(':Zone.Identifier')
            FileUtils.rm(file_path) rescue nil
            next
          end

          next unless file_path.match?(/\.(mp3|wav|flac|m4a)$/i)

          puts "\n New file detected: #{File.basename(file_path)}"
          AudioProcessor.call(file_path)
        end
      end

      @active_listener.start
    end

    def self.process_existing_files(directory)
      puts "Scanning for pre-existing files in: #{directory}"

      Dir.glob(File.join(directory, "**", "*.{mp3,wav,flac,m4a}")).each do |file_path|
        handle_file(file_path)
      end
    end

    def self.stop
      if @active_listener
        puts "Stopping active listener..."
        @active_listener.stop
        @active_listener = nil
      end
    end

    def self.handle_file(file_path)
      # 1. Clean up metadata ghosts
      if file_path.end_with?(':Zone.Identifier')
        FileUtils.rm(file_path) rescue nil
        return
      end

      # 2. Skip non-audio files
      return unless file_path.match?(/\.(mp3|wav|flac|m4a)$/i)

      puts "\n New file detected: #{File.basename(file_path)}"

      # 3. Isolate errors so one bad file doesn't crash the entire batch array
      begin
        AudioProcessor.call(file_path)
      rescue => e
        puts "ERROR processing #{File.basename(file_path)}: #{e.message}"
      end
    end

    def self.handle_file(file_path)
      # Clean up metadata ghosts
      if file_path.end_with?(':Zone.Identifier')
        FileUtils.rm(file_path) rescue nil
        return
      end
    end

    def self.restart(new_path)
      stop
      start(new_path)
      puts "WiredSound Listener re-started at: #{new_path}"
    end
  end
end