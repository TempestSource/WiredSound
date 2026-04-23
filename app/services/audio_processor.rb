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
  def self.fetch_single_song(mbid)
    token = get_auth_token
    return nil unless token

    response = HTTParty.get("#{API_BASE}/songs/#{mbid}",
                            headers: { "Authorization" => "Bearer #{token}" })

    response.success? ? response.parsed_response : nil
  end
  def self.fetch_single_artist(artist_id)
    token = get_auth_token
    return nil unless token
    response = HTTParty.get("#{API_BASE}/artists/#{artist_id}",
                            headers: { "Authorization" => "Bearer #{token}" })
    response.success? ? response.parsed_response : nil
  end
  def self.fetch_remote_artists
    token = get_auth_token
    return [] unless token

    response = HTTParty.get("#{API_BASE}/artists",
                            headers: { "Authorization" => "Bearer #{token}" })

    if response.success?
      return response.parsed_response
    else
      puts "Failed to fetch artists from API (Code: #{response.code})"
      return []
    end
  end
  def self.fetch_remote_albums
    token = get_auth_token
    return [] unless token
    response = HTTParty.get("#{API_BASE}/albums", headers: { "Authorization" => "Bearer #{token}" })
    response.success? ? response.parsed_response : []
  end
  def self.fetch_single_album(album_id)
    token = get_auth_token
    return nil unless token
    response = HTTParty.get("#{API_BASE}/albums/#{album_id}",
                            headers: { "Authorization" => "Bearer #{token}" })
    response.success? ? response.parsed_response : nil
  end


  def self.fetch_remote_songs
    token = get_auth_token
    return [] unless token

    response = HTTParty.get("#{API_BASE}/songs",
                            headers: { "Authorization" => "Bearer #{token}" })

    if response.success?
      return response.parsed_response
    else
      puts "Failed to fetch songs from API (Code: #{response.code})"
      return []
    end
  end

  def self.call(file_path)
    puts "--- Processing Audio File ---"

    token = get_auth_token
    return unless token

    new_hash = AudioHasher.call(file_path)
    if new_hash.nil? || new_hash.length != 32
      puts "Invalid Hash generated. Skipping entry."
      return
    end

    clean_filename = File.basename(file_path, ".*")
    song_name_for_file = clean_filename
    song_id_for_ui = "unrecognized_#{new_hash}"
    is_recognized = false

    match_data = AcoustidClient.identify_audio(file_path)
    mbid = match_data.is_a?(Hash) ? match_data[:songID] : match_data
    release_id = match_data.is_a?(Hash) ? match_data[:releaseID] : nil

    if mbid.present?
      if release_id.nil?
        puts "Release ID missing. Automatically searching MusicBrainz for a linked album..."
        release_id = MusicbrainzHelper.find_release_by_recording_id(mbid)
      end

      if release_id
        payload = {
          raw_hash: new_hash.to_s.strip,
          songID: mbid.to_s.strip,
          releaseID: release_id.to_s.strip
        }

        response = HTTParty.post("#{API_BASE}/entries",
                                 headers: {
                                   "Authorization" => "Bearer #{token}",
                                   "Content-Type" => "application/json"
                                 },
                                 body: payload.to_json
        )

        is_duplicate_hash = response.code == 400 && response.body.include?("Duplicate hash")

        if is_duplicate_hash
          puts "Known File: Hash exists. Sending PUT request to force API refresh..."
          refresh_response = HTTParty.put("#{API_BASE}/entries/#{mbid}",
                                          headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
                                          body: payload.to_json)

          response = refresh_response if refresh_response.success?
        end

        if response.success? || response.code == 409 || is_duplicate_hash
          puts "API ready! Waiting for hydration..."

          sleep 2

          song_response = HTTParty.get("#{API_BASE}/songs/#{mbid}",
                                       headers: { "Authorization" => "Bearer #{token}" }
          )

          if song_response.success? && song_response.parsed_response["songName"] == clean_filename
            puts "Server is still hydrating... retrying in 3 seconds..."
            sleep 3
            song_response = HTTParty.get("#{API_BASE}/songs/#{mbid}",
                                         headers: { "Authorization" => "Bearer #{token}" })
          end

          if song_response.success?
            api_name = song_response.parsed_response["songName"]
            if api_name && api_name != clean_filename
              puts "Metadata hydrated: #{api_name}"
              song_name_for_file = api_name
            else
              puts "Server provided no new name. Sticking with: #{clean_filename}"
              song_name_for_file = clean_filename
            end
            song_id_for_ui = mbid
            is_recognized = true
          else
            puts "Metadata GET failed. Using filename fallback."
            is_recognized = true
          end
        else
          puts "API Rejected Entry: #{response.code} - #{response.body}"
        end
      else
        puts "Still missing Release ID for #{clean_filename}."
      end
    else
      puts "No AcoustID match found for #{clean_filename}."
    end

    target_folder = is_recognized ? 'library' : 'unrecognized'
    final_dir = Rails.root.join('storage', target_folder)
    FileUtils.mkdir_p(final_dir)

    stable_filename = is_recognized ? mbid : song_name_for_file
    destination_path = final_dir.join("#{stable_filename}#{File.extname(file_path)}")

    if File.exist?(destination_path)
      puts "Duplicate: physical file already exists in #{target_folder}. Removing incoming copy."
      FileUtils.rm(file_path) if File.exist?(file_path)
    elsif File.exist?(file_path)
      puts "Moving file to #{target_folder} as #{stable_filename}..."
      FileUtils.mv(file_path, destination_path)
    end

    ui_song = OpenStruct.new(
      songID: song_id_for_ui,
      songName: song_name_for_file,
      id: song_id_for_ui,
      artist_infos: [OpenStruct.new(artistName: "Identifying...")],
      album_release: OpenStruct.new(album_info: OpenStruct.new(albumName: "Unknown Album")),
      trackNumber: "N/A"
    )

    def ui_song.to_model; self; end
    def ui_song.model_name; ActiveModel::Name.new(SongInfo); end
    def ui_song.to_key; [songID]; end
    def ui_song.persisted?; true; end
    def ui_song.param_key; "song"; end
    def ui_song.to_param; songID; end

    if is_recognized
      Turbo::StreamsChannel.broadcast_append_to(
        "notifications_channel",
        target: "flash-notifications",
        partial: "songs/success_alert",
        locals: { song: ui_song }
      )

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