require 'httparty'
require 'nokogiri'

class MetadataHelper
  # 1. The Fallback Search (Fixes the crash)
  def self.search_by_filename(query)
    # Clean hyphens so they don't break the search engine's logic
    clean_query = query.tr('-', ' ')

    url = "https://musicbrainz.org/ws/2/recording?query=#{CGI.escape(clean_query)}&limit=1"
    response = HTTParty.get(url, headers: { 'User-Agent' => 'WiredSound/1.0' })
    return nil unless response.success?

    xml = Nokogiri::XML(response.body)

    # We MUST include the 'ext' namespace to read the confidence score
    ns = {
      'mb' => 'http://musicbrainz.org/ns/mmd-2.0#',
      'ext' => 'http://musicbrainz.org/ns/ext#-2.0'
    }

    node = xml.xpath('//mb:recording', ns).first
    return nil unless node

    # Extract the score and the title to see what the API is guessing
    score = node.xpath('@ext:score', ns).text.to_i
    title = node.xpath('./mb:title', ns).text

    # The Iron-Clad Threshold
    if score < 85
      puts "⚠️ Rejected weak match: '#{title}' (Score: #{score}/100)"
      return nil
    end

    # Secondary Safety Net: Reject literal "Sound Effect" matches unless requested
    if title.downcase == "sound effect" && !clean_query.downcase.include?("deskulling")
      puts "⚠️ Rejected generic 'Sound Effect' API garbage."
      return nil
    end

    node['id']
  end

  # 2. The Album Fetcher (Fixes the "Unknown Album" UI)
  # 2. The Album Fetcher (Fixes the "Unknown Album" UI)
  def self.get_album_info(mbid)
    # The Magic Fix: Adding '+media' exposes the track numbers!
    url = "https://musicbrainz.org/ws/2/recording/#{mbid}?inc=releases+media"
    response = HTTParty.get(url, headers: { 'User-Agent' => 'WiredSound/1.0' })
    return {} unless response.success?

    xml = Nokogiri::XML(response.body)
    ns = { 'mb' => 'http://musicbrainz.org/ns/mmd-2.0#' }

    # Grab the first release (album) associated with this recording
    release_node = xml.xpath('//mb:release', ns).first

    if release_node
      {
        album_id: release_node['id'],
        album_name: release_node.xpath('./mb:title', ns).text,
        # Extract the release date
        release_date: release_node.xpath('./mb:date', ns).text,
        # Dig deep into the media list to find the track number
        track_number: release_node.xpath('.//mb:medium-list/mb:medium/mb:track-list/mb:track/mb:number', ns).first&.text      }
    else
      {}
    end
  end
end