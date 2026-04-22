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
  def self.call(file_path)
    puts "--- Processing Audio File ---"

    token = get_auth_token
    return unless token

    new_hash = AudioHasher.call(file_path)
    return unless new_hash

    clean_filename = File.basename(file_path, ".*")
    is_recognized = false

    mbid = AcoustidClient.identify_audio(file_path) || MetadataHelper.search_by_filename(clean_filename)

    song_name_for_file = clean_filename
    song_id_for_ui = "unrecognized_#{new_hash}"

    if mbid.present?
      puts "AcoustID Match Found! Syncing with Gatekeeper..."

      response = HTTParty.post("#{API_BASE}/entries",
                               headers: {
                                 "Authorization" => "Bearer #{token}",
                                 "Content-Type" => "application/json"
                               },
                               body: { raw_hash: new_hash, songID: mbid }.to_json
      )

      if response.success? || response.code == 409
        puts "API accepted the entry! Fetching metadata..."

        song_response = HTTParty.get("#{API_BASE}/songs/#{mbid}",
                                     headers: { "Authorization" => "Bearer #{token}" }
        )

        if song_response.success?
          song_name_for_file = song_response.parsed_response["songName"] || clean_filename
          song_id_for_ui = mbid
          is_recognized = true
        end
      else
        puts "API rejected the entry (Code: #{response.code}). Proceeding as unrecognized."
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