require 'httparty'

class MusicbrainzHelper
  BASE_URL = "https://musicbrainz.org/ws/2"

  def self.find_release_by_recording_id(mbid)
    response = HTTParty.get("#{BASE_URL}/recording/#{mbid}",
                            query: { inc: "releases", fmt: "json" }, # Keep it simple
                            headers: { "User-Agent" => "WiredSound/1.0 (user@email.com)" }
    )

    return nil unless response.success?
    data = response.parsed_response

    if data['releases']&.any?
      sorted = data['releases'].sort_by { |r| r['date'] || '9999-12-31' }

      puts "Found #{sorted.count} releases. Selecting oldest: #{sorted.first['title']}"
      return sorted.first['id']
    end

    title = data['title']
    artist = data['artist-credit']&.first&.dig('artist', 'name')

    puts "Searching for other releases of '#{title}' by '#{artist}'..."
    search_query = "recording:\"#{title}\" AND artist:\"#{artist}\""

    search_response = HTTParty.get("#{BASE_URL}/recording",
                                   query: { query: search_query, fmt: "json" },
                                   headers: { "User-Agent" => "WiredSound/1.0 (user@email.com)" }
    )

    if search_response.success?
      search_response.parsed_response['recordings']&.each do |rec|
        if rec['releases']&.any?
          return rec['releases'].first['id']
        end
      end
    end

    nil
  end
end