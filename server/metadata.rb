# frozen_string_literal: true

require 'httparty'
require 'nokogiri'
require 'uri'
require 'securerandom'
# THE UPDATED DATABASE ARCHITECTURE:
# - Songs: songID, songName, albumID (Links directly to Album!)
# - Artists: artistID, artistName
# - Albums: albumID, albumName
# - Junctions: song_artists & album_artists handle the Many-to-Many links.

class Metadata
  def initialize
    @url = 'https://musicbrainz.org/ws/2/'
    @user_agent = 'WiredSound/0.1 ( https://github.com/adstahly/WiredSound )'
    @ns = { 'mb' => 'http://musicbrainz.org/ns/mmd-2.0#' }
  end
  ### Front Door for AudioProcessor
  def self.get_search_result(filepath)
    new.perform_search(filepath)
  end

  def perform_search(filepath)
    # 1. Plan A: Use AcoustID fingerprinting for a perfect match
    mbid = AcoustidClient.identify_audio(filepath)

    if mbid
      puts "✅ AcoustID match! Fetching metadata for MBID: #{mbid}..."
      fetch_by_mbid(mbid)
    else
      # 2. Plan B: Fallback to fuzzy filename search if fingerprinting fails
      puts "⚠️ AcoustID failed or no match. Falling back to fuzzy filename search..."

      # Clean the filename (remove extension and special characters)
      clean_name = File.basename(filepath, ".*").gsub(/[^a-zA-Z0-9\s]/, ' ')
      fuzzy_search(clean_name)
    end
  end

  private

  # Fetches details for a specific MBID, prioritizing full albums over singles
  def fetch_by_mbid(mbid)
    # We include 'releases' and 'release-groups' to check for album types
    node = sub_request('recording', mbid, 'artists+releases+release-groups')
    return nil unless node

    recording = parse_first(node, '//mb:recording')
    return nil unless recording

    # Logic to find the best release (Prefer 'Album' over 'Single' or 'EP')
    all_releases = node.xpath('//mb:release', @ns)
    best_release = all_releases.find do |r|
      type = parse_first(r, './/mb:release-group')&.[]('type')
      type == 'Album'
    end || all_releases.first

    map_metadata_hash(recording, best_release)
  end

  # Performs a fuzzy text search if the fingerprint isn't found
  def fuzzy_search(query, retries = 3)
    sleep(1) # Rate limit
    encoded_query = URI.encode_www_form_component(query)

    begin
      response = HTTParty.get("#{@url}recording?query=#{encoded_query}&limit=5", headers: { 'User-Agent' => @user_agent })
      xml = Nokogiri::XML(response.to_s)

      recording = parse_first(xml, '//mb:recording')
      return nil unless recording

      release = parse_first(recording, './/mb:release')
      map_metadata_hash(recording, release)
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError, Net::OpenTimeout, Net::ReadTimeout => e
      puts "⚠️ Network error during fuzzy search (#{e.class}). Retries left: #{retries}"
      return nil if retries <= 0
      fuzzy_search(query, retries - 1)
    end
  end

  # Helper to standardize the output format for the AudioProcessor
  # Helper to standardize the output format for the AudioProcessor
  # Helper to standardize the output format for the AudioProcessor
  # Updated helper to standardize the output format
  # Helper to standardize the output format for the AudioProcessor
  # Updated helper to standardize the output format for the AudioProcessor
  # Helper to standardize the output format for the AudioProcessor
  def map_metadata_hash(recording, release)
    # 1. The "Nuclear Option" XPath: Ignores namespaces entirely to find the artist data
    artist_name = recording.xpath('.//*[local-name()="artist-credit"]//*[local-name()="name"]').first&.text ||
                  release&.xpath('.//*[local-name()="artist-credit"]//*[local-name()="name"]')&.first&.text ||
                  "Unknown Artist"

    artist_id = recording.xpath('.//*[local-name()="artist"]').first&.[]('id') ||
                release&.xpath('.//*[local-name()="artist"]')&.first&.[]('id') ||
                "art_#{SecureRandom.hex(12)}"

    # 2. Safety Net Debugger (Prints the XML if it fails so we can see the real structure)
    if artist_name == "Unknown Artist"
      puts "🚨 DEBUG: Artist not found! Dumping raw XML structure:"
      puts recording.to_xml.lines.first(20).join
    end

    {
      artist_name: artist_name,
      album_name: release ? parse_first(release, './mb:title')&.text : "Unknown Album",
      song_name: parse_first(recording, './mb:title')&.text || "Unknown Song",
      artist_id: artist_id,
      album_id: release ? release['id'] : "alb_#{SecureRandom.hex(12)}",
      song_id: recording['id'] || "sng_#{SecureRandom.hex(12)}"
    }
  end

  ### Basic HTTP Outlines (Fixed Infinite Loops & SSL Drops)

  def request(entity, mbid, retries = 3)
    sleep(1)
    begin
      response = HTTParty.get("#{@url}#{entity}/#{mbid}", headers: { 'User-Agent' => @user_agent })
      Nokogiri::XML(response.to_s)
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError, Net::OpenTimeout, Net::ReadTimeout => e
      puts "⚠️ Network error (#{e.class}). Retries left: #{retries}"
      return nil if retries <= 0
      request(entity, mbid, retries - 1)
    end
  end

  def sub_request(entity, mbid, subsearch, retries = 3)
    sleep(1)
    begin
      response = HTTParty.get("#{@url}#{entity}/#{mbid}?inc=#{subsearch}", headers: { 'User-Agent' => @user_agent })
      Nokogiri::XML(response.to_s)
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError, Net::OpenTimeout, Net::ReadTimeout => e
      puts "⚠️ Network error (#{e.class}). Retries left: #{retries}"
      return nil if retries <= 0
      sub_request(entity, mbid, subsearch, retries - 1)
    end
  end

  def linked_request(entity, mbid, link, retries = 3)
    sleep(1)
    begin
      response = HTTParty.get("#{@url}#{entity}?#{link}=#{mbid}", headers: { 'User-Agent' => @user_agent })
      Nokogiri::XML(response.to_s)
    rescue Errno::ECONNRESET, OpenSSL::SSL::SSLError, EOFError, Net::OpenTimeout, Net::ReadTimeout => e
      puts "⚠️ Network error (#{e.class}). Retries left: #{retries}"
      return nil if retries <= 0
      linked_request(entity, mbid, link, retries - 1)
    end
  end

  ### Parse Helpers
  def parse_item(node, path)
    node.xpath(path.to_s, @ns)
  end

  def parse_first(node, path)
    node.xpath(path.to_s, @ns).first
  end

  def map_ids(node, item)
    node.xpath(".//mb:#{item}", @ns).map { |cur| cur['id'] }
  end

  ### Processor Helpers
  def title(song_id)
    node = request('recording', song_id)
    parse_item(node, '//mb:title').text
  end

  def album_artists(release_id)
    node = sub_request('release', release_id, 'artist-credits')
    map_ids(node, 'artist')
  end

  def album_releases(album_id)
    node = linked_request('release', album_id, 'recording')
    node.xpath('//mb:release', @ns).map do |cur|
      [
        cur['id'],
        *%w[title status date barcode].map do |data|
          parse_first(cur, "./mb:#{data}").text
        end
      ]
    end
  end

  def release_songs(release)
    medium = parse_first(release, '//mb:medium')
    track_num = 0
    medium.xpath('.//mb:recording', @ns).map do |cur|
      track_num += 1
      [cur['id'], track_num, parse_item(cur, './/mb:title').text]
    end
  end

  def song_artists(song_id)
    node = linked_request('artist', song_id, 'recording')
    node.xpath('//mb:artist', @ns).map do |cur|
      [
        cur['id'],
        cur['type'],
        *%w[name country begin].map { |data| parse_first(cur, ".//mb:#{data}").text }
      ]
    end
  end
end