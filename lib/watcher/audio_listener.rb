require "listen"

class AudioListener
  def self.start
    watch_directory = Rails.root.join("storage", "incoming_music").to_s

    FileUtils.mkdir_p(watch_directory)

    puts "WiredSound Listener started!"
    puts "Watching for new audio files in: #{watch_directory}"

    listener = Listen.to(watch_directory, only: /\.(mp3|wav|flac|m4a)$/i) do |modified, added, removed|
      added.each do |file_path|
        puts "\n New file detected: #{File.basename(file_path)}"

        AudioProcessor.call(file_path)
      end
    end

    listener.start

    sleep
  end
end
