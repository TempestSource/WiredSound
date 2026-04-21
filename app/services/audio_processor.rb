require 'fileutils'
require 'httparty' # We use HTTParty to talk to Soyber's server now
require 'ostruct'

class AudioProcessor
  # Point this to Soyber's live server
  API_BASE = "http://#{ENV['SOYBER_IP']}:3000/api"

  def self.get_auth_token
    return @auth_token if @auth_token

    puts "🔑 Logging in as 'lain' to get API token..."
    response = HTTParty.post("#{API_BASE}/v1/auth/login", body: {
      username: "lain",
      password: ENV['LAIN_PASSWORD'] # Fetches from your .env file
    })

    def self.call(file_path)
      puts "--- Processing Audio File ---"

      new_hash = AudioHasher.call(file_path)
      return unless new_hash

      clean_filename = File.basename(file_path, ".*")
      is_recognized = false

      # 1. Ask AcoustID for the MusicBrainz ID
      mbid = AcoustidClient.identify_audio(file_path) || MetadataHelper.search_by_filename(clean_filename)

      song_name_for_file = clean_filename
      song_id_for_ui = "unrecognized_#{new_hash}"

      if mbid.present?
        puts "✅ AcoustID Match Found! Sending to Soyber's Gatekeeper API..."

        # 2. Send the data to Soyber's Server to do the heavy lifting
        # Note: If AcoustID doesn't give you a releaseID, you may need to ask Soyber if his API allows it to be blank
        response = HTTParty.post("#{API_BASE}/entries", body: {
          raw_hash: new_hash,
          songID: mbid
        })

        if response.success? || response.code == 409 # 409 usually means it already exists!
          puts "✅ API accepted the entry! Fetching official name to rename local file..."

          # 3. Ask Soyber's server for the official song data so we can rename the file locally
          song_response = HTTParty.get("#{API_BASE}/songs/#{mbid}")

          if song_response.success?
            song_name_for_file = song_response.parsed_response["songName"] || clean_filename
            song_id_for_ui = mbid
            is_recognized = true
          end
        else
          puts "⚠️ API rejected the entry (Code: #{response.code}). Proceeding as unrecognized."
        end
      else
        puts "⚠️ No AcoustID match found. Proceeding as unrecognized."
      end

      # 4. Move the physical file to the correct folder
      target_folder = is_recognized ? 'library' : 'unrecognized'
      final_dir = Rails.root.join('storage', target_folder)
      FileUtils.mkdir_p(final_dir)
      destination_path = final_dir.join("#{song_name_for_file}#{File.extname(file_path)}")

      if File.exist?(destination_path)
        puts "Duplicate: physical file already exists in #{target_folder}."
        FileUtils.rm(file_path) if File.exist?(file_path)
      else
        FileUtils.mv(file_path, destination_path)
      end

      # 5. Broadcast to the UI
      ui_song = OpenStruct.new(
        songID: song_id_for_ui,
        songName: song_name_for_file,
        id: song_id_for_ui,
        # Add these stubs to satisfy the view associations
        artist_infos: [],
        album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Unknown Album")),
        trackNumber: "N/A"
      )

      # These singleton methods trick Rails view helpers
      def ui_song.to_model
        self;
      end

      def ui_song.model_name
        ActiveModel::Name.new(SongInfo);
      end

      def ui_song.to_key
        [songID];
      end

      def ui_song.persisted?
        true;
      end

      def ui_song.param_key
        "song";
      end

      Turbo::StreamsChannel.broadcast_append_to(
        "notifications_channel",
        target: "flash-notifications",
        partial: "songs/success_alert",
        locals: { song: ui_song }
      )

      if is_recognized
        Turbo::StreamsChannel.broadcast_prepend_to(
          "notifications_channel",
          target: "recognized-songs-list",
          partial: "songs/song",
          locals: { song: ui_song }
        )
      end

      return ui_song
    end
  end
end
