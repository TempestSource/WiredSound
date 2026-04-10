# frozen_string_literal: true

require 'open3'
require 'json'
require 'shellwords'
require 'httparty'

class AcoustidClient
  # Step 1: Generate the acoustic fingerprint using the system's fpcalc tool
  def self.generate_fingerprint(filepath)
    # The -json flag tells fpcalc to format the output perfectly for Ruby to read
    command = "fpcalc -json #{Shellwords.escape(filepath)}"

    # Open3 captures the standard output, standard error, and the exit status
    stdout, stderr, status = Open3.capture3(command)

    unless status.success?
      puts "❌ fpcalc failed: #{stderr}"
      return nil
    end

    # Parse the JSON output into a Ruby hash
    data = JSON.parse(stdout)

    # We need both the duration and the fingerprint to query AcoustID
    {
      duration: data['duration'].to_i,
      fingerprint: data['fingerprint']
    }
  rescue StandardError => e
    puts "❌ Error generating fingerprint: #{e.message}"
    nil
  end
  # Add this to the very top of the file if it isn't there already:

  # Step 2: Send the fingerprint to the API and extract the MusicBrainz ID
  def self.fetch_mbid(duration, fingerprint)
    api_key = ENV['ACOUSTID_API_KEY']

    unless api_key
      puts "❌ Error: Missing ACOUSTID_API_KEY in .env file!"
      return nil
    end

    url = 'https://api.acoustid.org/v2/lookup'
    query_params = {
      client: api_key,
      meta: 'recordings',
      duration: duration,
      fingerprint: fingerprint
    }

    begin
      # Send the GET request to AcoustID
      response = HTTParty.get(url, query: query_params, timeout: 5)
      data = JSON.parse(response.body)

      # Check if the API request was successful and returned matches
      if data['status'] == 'ok' && data['results'].any?
        # AcoustID sorts results by confidence score automatically.
        # We grab the very first result, and extract its first MusicBrainz Recording ID.
        best_match = data['results'].first

        if best_match['recordings'] && best_match['recordings'].any?
          mbid = best_match['recordings'].first['id']
          puts "✅ AcoustID Match Found! MusicBrainz ID: #{mbid}"
          return mbid
        end
      end

      puts "⚠️ No matching acoustic fingerprint found in the database."
      nil
    rescue StandardError => e
      puts "❌ AcoustID API Request Failed: #{e.message}"
      nil
    end
  end
  # Step 3: The Wrapper Method for the AudioProcessor
  def self.identify_audio(filepath)
    puts "🔍 Analyzing acoustic fingerprint for: #{File.basename(filepath)}..."

    # 1. Generate the fingerprint using fpcalc
    audio_data = generate_fingerprint(filepath)

    # If fpcalc failed (e.g., corrupted file), safely exit
    return nil unless audio_data

    # 2. Send the fingerprint to AcoustID and return the resulting MusicBrainz ID
    fetch_mbid(audio_data[:duration], audio_data[:fingerprint])
  end
end