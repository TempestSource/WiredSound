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
      puts "❌ Error: ACOUSTID_API_KEY environment variable is not set."
      return nil
    end

    url = 'https://api.acoustid.org/v2/lookup'
    query_params = {
      client: api_key,
      duration: duration,
      meta: 'recordings releases', # We must request release data
      fingerprint: fingerprint
    }

    begin
      # Add 'require "pp"' at the top of your file
      response = HTTParty.get(url, query: query_params, timeout: 5)
      data = JSON.parse(response.body)

      # This will print the entire structure to your terminal for review
      puts "--- FULL API RESPONSE ---"
      pp data

      if data['status'] == 'ok' && data['results'].any?

        # UPGRADE: Smart Iteration
        # Loop through all fingerprint matches instead of just taking the first one
        data['results'].each do |match|
          match['recordings']&.each do |recording|
            puts "Recording ID: #{recording['id']}"

            # This is where you review the releases array
            if recording['releases']&.any?
              recording['releases'].each do |release|
                puts "  - Release Found: #{release['title']} (ID: #{release['id']})"
              end
            else
              puts "  - ⚠️ No releases linked to this recording."
            end
          end
        end

        # FALLBACK: We searched every single result and found absolutely NO releases.
        # This usually means it's a digital single or a very obscure track.
        # We return just the song ID, and let the AudioProcessor handle the missing release.
        first_recording = data['results'].first['recordings']&.first
        if first_recording
          mbid = first_recording['id']
          puts "⚠️ Partial Match: Found Song ID (#{mbid}) but MusicBrainz has no album data."
          return { songID: mbid, releaseID: nil }
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
  def self.find_release_for_track(title, artist)
    puts "🔍 Deep Search: Finding an official release for '#{title}' by '#{artist}'..."

    # Use MusicBrainz search to find recordings matching the identified title and artist
    # This is metadata search, NOT filename search.
    url = "https://musicbrainz.org/ws/2/recording"
    query = "recording:\"#{title}\" AND artist:\"#{artist}\""

    response = HTTParty.get(url,
                            query: { query: query, fmt: 'json' },
                            headers: { "User-Agent" => "WiredSound/1.0 (adam@aurora.edu)" }
    )

    if response.success?
      recordings = response.parsed_response['recordings'] || []

      # Iterate through all matched recordings
      recordings.each do |rec|
        # Check if this specific recording entry has any releases linked
        if rec['releases']&.any?
          release = rec['releases'].first
          puts "✅ Found Release: #{release['title']} (ID: #{release['id']})"
          return release['id']
        end
      end
    end

    nil
  end
end