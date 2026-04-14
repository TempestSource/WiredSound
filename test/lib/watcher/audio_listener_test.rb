require "test_helper"
require "fileutils"
require Rails.root.join("lib", "watcher", "audio_listener")

class AudioListenerTest < ActiveSupport::TestCase
  test "it scans the directory and processes existing audio files" do
    watch_dir = Rails.root.join('tmp', 'test_incoming_music').to_s
    FileUtils.mkdir_p(watch_dir)

    dummy_file = File.join(watch_dir, "test_song.mp3")
    FileUtils.touch(dummy_file)

    processed_file = nil
    original_processor_call = AudioProcessor.method(:call)

    begin
      AudioProcessor.define_singleton_method(:call) do |file, meta = {}|
        processed_file = file
      end

      Watcher::AudioListener.process_existing_files(watch_dir)
    ensure
      AudioProcessor.define_singleton_method(:call, &original_processor_call)
      FileUtils.rm_rf(watch_dir)
    end

    assert_equal dummy_file, processed_file, "AudioProcessor was not called with the correct file"
  end
end