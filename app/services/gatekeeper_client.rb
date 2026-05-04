# app/services/gatekeeper_client.rb
require 'httparty'

class GatekeeperClient
  API_BASE = "#{ENV['API_URL']}"
  @auth_token = nil

  class << self
    def get_auth_token
      return @auth_token if @auth_token

      puts "Logging in as 'lain' to Gatekeeper API..."
      response = HTTParty.post("#{API_BASE}/v1/auth/login",
                               headers: { 'Content-Type' => 'application/json' },
                               body: {
                                 username: "lain",
                                 password: ENV['LAIN_PASSWORD']
                               }.to_json
      )

      if response.success?
        @auth_token = response.parsed_response["access_token"]
        puts "Gatekeeper Token acquired!"
        @auth_token
      else
        puts "Gatekeeper Login failed (Code: #{response.code})."
        nil
      end
    end

    def create_entry(raw_hash:, song_id:, release_id:)
      token = get_auth_token
      return nil unless token

      payload = {
        raw_hash: raw_hash,
        songID: song_id,
        releaseID: release_id
      }

      puts "DEBUG: [Gatekeeper POST Payload] #{payload.inspect}"
      puts "Sending POST /api/entries for hydration..."

      response = HTTParty.post("#{API_BASE}/entries",
                               headers: {
                                 "Authorization" => "Bearer #{token}",
                                 "Content-Type" => "application/json"
                               },
                               body: payload.to_json
      )

      if response.success?
        puts "Entry created and hydration started!"
        response.parsed_response
      else
        puts "Failed to create entry (Code: #{response.code})."
        nil
      end
    end

    # app/services/gatekeeper_client.rb

    # Add this method to check the remote /api/hashes endpoint
    def remote_hash_exists?(hash_str)
      response = authenticated_get("/hashes/#{hash_str}")
      response.present?
    end
    def reset_token!
      @auth_token = nil
    end

    # --- Songs ---
    def fetch_single_song(mbid)
      authenticated_get("/songs/#{mbid}")
    end

    def fetch_remote_songs
      authenticated_get("/songs", default: [])
    end

    # --- Artists ---
    def fetch_single_artist(artist_id)
      authenticated_get("/artists/#{artist_id}")
    end

    def fetch_remote_artists
      authenticated_get("/artists", default: [])
    end

    # --- Albums ---
    def fetch_single_album(album_id)
      authenticated_get("/albums/#{album_id}")
    end

    def fetch_remote_albums
      authenticated_get("/albums", default: [])
    end
    def download_release_cover(release_id)
      token = get_auth_token
      return false unless token

      url = "#{API_BASE}/albums/#{release_id}/cover"

      puts "Downloading cover from Gatekeeper: #{url}"

      response = HTTParty.get(url, headers: { "Authorization" => "Bearer #{token}" })

      if response.success?
        # Ensure the covers directory exists
        FileUtils.mkdir_p(Rails.root.join('public', 'covers'))

        local_path = Rails.root.join('public', 'covers', "#{release_id}.jpg")

        File.open(local_path, 'wb') do |f|
          f.write(response.body)
        end

        true
      else
        puts "Failed to download remote cover (Code: #{response.code})"
        false
      end
    end
    private

    def authenticated_get(endpoint, default: nil)
      token = get_auth_token
      return default unless token

      response = HTTParty.get("#{API_BASE}#{endpoint}",
                              headers: { "Authorization" => "Bearer #{token}" })

      if response.success?
        response.parsed_response
      else
        puts "Gatekeeper API Error on #{endpoint} (Code: #{response.code})"
        default
      end
    end
  end
end