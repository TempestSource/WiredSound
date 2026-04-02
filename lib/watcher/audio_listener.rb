module Watcher
  class AudioListener
    @polling_thread = nil
    @active = false

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
    end

    def self.handle_file(file_path)
      if file_path.end_with?(':Zone.Identifier')
        FileUtils.rm(file_path) rescue nil
        return
      end

      return unless file_path.match?(/\.(mp3|wav|flac|m4a)$/i)

      puts "\n New file detected: #{File.basename(file_path)}"

      begin
        AudioProcessor.call(file_path)
      rescue => e
        puts "ERROR processing #{File.basename(file_path)}: #{e.message}"
      end
    end

    def self.restart(new_path)
      stop
      start(new_path)
      puts "WiredSound Listener re-started at: #{new_path}"
    end
  end
end