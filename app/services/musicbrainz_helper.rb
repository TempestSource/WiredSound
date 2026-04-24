# app/services/musicbrainz_helper.rb
require 'httparty'

class MusicbrainzHelper
  BASE_URL = "https://musicbrainz.org/ws/2"

  def self.find_release_by_recording_id(mbid)
    # Step A: Look up the Recording ID to get the official Title/Artist
    # We include 'releases' and 'artist-credits'
    response = HTTParty.get("#{BASE_URL}/recording/#{mbid}",
                            query: { inc: "releases+artist-credits", fmt: "json" },
                            headers: { "User-Agent" => "WiredSound/1.0 (adam@aurora.edu)" }
    )

    return nil unless response.success?
    data = response.parsed_response

    # Step B: If the recording has a release, return it immediately
    if data['releases']&.any?
      return data['releases'].first['id']
    end

    # Step C: If it's a "loose" recording (like Q), search for other recordings of the same title
    title = data['title']
    artist = data['artist-credit']&.first&.dig('artist', 'name')

    puts "Searching for other releases of '#{title}' by '#{artist}'..."
    search_query = "recording:\"#{title}\" AND artist:\"#{artist}\""

    search_response = HTTParty.get("#{BASE_URL}/recording",
                                   query: { query: search_query, fmt: "json" },
                                   headers: { "User-Agent" => "WiredSound/1.0 (adam@aurora.edu)" }
    )

    if search_response.success?
      # Look for any recording in the search results that HAS a release
      search_response.parsed_response['recordings']&.each do |rec|
        if rec['releases']&.any?
          return rec['releases'].first['id']
        end
      end
    end

    nil
  end
end