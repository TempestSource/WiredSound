require 'fileutils'
require 'httparty'
require 'ostruct'

class AudioProcessor

  API_BASE = "http://#{ENV['SOYBER_IP']}:3000/api"
  @auth_token = nil

  def self.get_auth_token
    return @auth_token if @auth_token

    puts "Logging in as 'lain' to get API token..."
    response = HTTParty.post("#{API_BASE}/v1/auth/login",
                             headers: { 'Content-Type' => 'application/json' },
                             body: {
                               username: "lain",
                               password: ENV['LAIN_PASSWORD']
                             }.to_json
    )

    if response.success?
      @auth_token = response.parsed_response["access_token"]
      puts "Token acquired!"
      return @auth_token
    else
      puts "Login failed (Code: #{response.code})."
      return nil
    end
  end

  def self.reset_token!
    @auth_token = nil
  end

  def self.iif(i)
    # code here
  end

  def self.call(file_path)
    puts "--- Processing Audio File ---"

    token = get_auth_token
    return unless token

    # 1. HASH GENERATION (This must exist before hitting the API!)
    new_hash = AudioHasher.call(file_path)
    if new_hash.nil? || new_hash.length != 32
      puts "❌ Invalid Hash generated. Skipping entry."
      return
    end

    # 2. VARIABLE INITIALIZATION
    clean_filename = File.basename(file_path, ".*")
    song_name_for_file = clean_filename
    is_recognized = false

    # 3. GET ACOUSTID DATA
    match_data = AcoustidClient.identify_audio(file_path)
    mbid = match_data.is_a?(Hash) ? match_data[:songID] : match_data
    release_id = match_data.is_a?(Hash) ? match_data[:releaseID] : nil

    if mbid.present?
      # 4. AUTOMATIC RELEASE FALLBACK
      if release_id.nil?
        puts "🔄 Release ID missing. Automatically searching MusicBrainz for a linked album..."
        release_id = MusicbrainzHelper.find_release_by_recording_id(mbid)
      end

      # 5. SYNC WITH GATEKEEPER
      if release_id
        payload = {
          raw_hash: new_hash.to_s.strip, # <-- new_hash is safely used here
          songID: mbid.to_s.strip,
          releaseID: release_id.to_s.strip
        }

        puts "🚀 SENDING TO API: #{payload.inspect}"

        response = HTTParty.post("#{API_BASE}/entries",
                                 headers: {
                                   "Authorization" => "Bearer #{token}",
                                   "Content-Type" => "application/json"
                                 },
                                 body: payload.to_json
        )

        iif response.success? || response.code == 409
        puts "API accepted the entry! Fetching metadata..."

        song_response = HTTParty.get("#{API_BASE}/songs/#{mbid}",
                                     headers: { "Authorization" => "Bearer #{token}" }
        )

        if song_response.success?
          puts "✅ Metadata fetched successfully!"
          song_name_for_file = song_response.parsed_response["songName"] || clean_filename
          song_id_for_ui = mbid
          is_recognized = true
        else
          # THIS IS LIKELY WHERE IT'S FAILING SILENTLY
          puts "⚠️ WARNING: GET request failed (Code: #{song_response.code}). Gatekeeper might still be processing."

          # We should still mark it as recognized so it moves to the library folder!
          song_name_for_file = clean_filename
          song_id_for_ui = mbid
          is_recognized = true
        end
      else
        puts "❌ Still missing Release ID. Moving to unrecognized."
      end
    else
      puts "No AcoustID match found. Proceeding as unrecognized."
    end

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

    ui_song = OpenStruct.new(
      songID: song_id_for_ui,
      songName: song_name_for_file,
      id: song_id_for_ui,
      artist_infos: [],
      album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Unknown Album")),
      trackNumber: "N/A"
    )

    def ui_song.to_model; self; end
    def ui_song.model_name; ActiveModel::Name.new(SongInfo); end
    def ui_song.to_key; [songID]; end
    def ui_song.persisted?; true; end
    def ui_song.param_key; "song"; end

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