require "test_helper"
require "listen"
require Rails.root.join("lib", "watcher", "audio_listener")

class AudioListenerTest < ActiveSupport::TestCase
  test "it starts watching the directory and processes new audio files" do
    watch_dir = Rails.root.join('storage', 'incoming_music').to_s
    dummy_file = "#{watch_dir}/test_song.mp3"

    processed_file = nil
    captured_dir = nil
    captured_options = nil

    original_processor_call = AudioProcessor.method(:call)

    begin
      AudioProcessor.define_singleton_method(:call) do |file, meta = {}|
        processed_file = file
      end

      fake_listener = Object.new
      def fake_listener.start; end

      Listen.define_singleton_method(:to) do |dir, options, &block|
        captured_dir = dir
        captured_options = options

        block.call([], [dummy_file], [])
        fake_listener
      end

      AudioListener.define_singleton_method(:sleep) { nil }

      AudioListener.start

    ensure
      AudioProcessor.define_singleton_method(:call, &original_processor_call)
    end

    assert_equal watch_dir, captured_dir
    assert_equal /\.(mp3|wav|flac|m4a)$/i, captured_options[:only]
    assert_equal dummy_file, processed_file, "AudioProcessor was not called with the new file"
  end
end