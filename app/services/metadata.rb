# frozen_string_literal: true

require 'httparty'
require 'nokogiri'
require 'fileutils'

# The Database has 3 major components:
# - songs (recordings), artists and albums
#
# The following ignores IDs corresponding to table keys and tables for many <-> many relationships
# Songs are fairly straightforward and refer to a specific recording of a song
#   - songName, [artistID(s)], releaseID(specific album release), trackNumber
# Artists are the most straightforward
#   - artistName, [artistAlias(es)], [albumID(releaseGroup)]
# Albums have both a release group entry and a specific recording entry to account for significantly different releases
#   - Release Group: albumName, [artistID(s)], coverPath(future), [releaseID(s)]]
#   - Specific Release: [recordingID(s)], releaseDate

# TODO:
#   - Better rate limiting system
#   - Better connection fail handling
#   - Cover Images

class Metadata


  class << self

    # Metadata Source URL & User Agent
    URL = 'https://musicbrainz.org/ws/2/'
    COVERS = 'https://coverartarchive.org/release/'
    USER_AGENT = 'WiredSound/0.1'
    NS = { 'mb' => 'http://musicbrainz.org/ns/mmd-2.0#' }
    COVER_PATH = ENV.fetch('COVER_PATH', Rails.root.join('public', 'covers'))

    ### Basic HTTP outlines

    def request(entity, mbid)
      sleep(1)
      begin
        response = HTTParty.get(URL + "#{entity}/#{mbid}",
                                headers: { 'User-Agent' => USER_AGENT })
      rescue Errno::ECONNRESET => e
        response = request(entity, mbid)
      end
      Nokogiri::XML(response.to_s)
    end

    def sub_request(entity, mbid, subsearch)
      sleep(1)
      begin
        response = HTTParty.get(URL + "#{entity}/#{mbid}?inc=#{subsearch}",
                                headers: { 'User-Agent' => USER_AGENT })
      rescue Errno::ECONNRESET => e
        response = sub_request(entity, mbid, subsearch)
      end
      Nokogiri::XML(response.to_s)
    end

    def linked_request(entity, mbid, link)
      sleep(1)
      begin
        response = HTTParty.get(URL + "#{entity}?#{link}=#{mbid}",
                                headers: { 'User-Agent' => USER_AGENT })
      rescue Errno::ECONNRESET => e
        response = linked_request(entity, mbid, link)
      end
      Nokogiri::XML(response.to_s)
    end

    def cover_request(mbid)
      sleep(1)
      begin
        response = HTTParty.get("#{COVERS}#{mbid}/front",
                                headers: { 'User-Agent' => USER_AGENT })


        if [301, 302, 307, 308].include?(response.code)
          redirect_url = response.headers['location']
          response = HTTParty.get(redirect_url, headers: { 'User-Agent' => USER_AGENT })
        end

        response.code == 200 ? response.body : nil
      rescue StandardError => e
        puts "Cover Archive Error: #{e.message}"
        nil
      end
    end

    ### Parse Helpers
    def parse_item(node, path)
      node.xpath("#{path}", NS)
    end

    # Circumvents having 3x song count for 'Pink Pantheress - Fancy Some More?'
    def parse_first(node, path)
      node.xpath("#{path}", NS).first
    end

    def map_ids(node, item)
      node.xpath(".//mb:#{item}", NS).map do |cur|
        cur['id']
      end
    end

    ### Main Processors

    # songID, songName, [song -> artists]
    def process_song(song_id)
      [song_id, title(song_id), song_artists(song_id)]
    end

    # TODO: this does 3 API requests which is awful
    # TODO: releaseDate
    # releaseID, albumID, albumType, [album -> artists], [release -> songs]
    def process_release(release_id)
      release = sub_request('release', release_id, 'recordings')
      rg_request = linked_request('release-group', release_id, 'release')
      rg = parse_first(rg_request, '//mb:release-group')
      cover(release_id)
      [
        release_id,
        rg['id'],
        rg['type'],
        parse_first(release, './/mb:title')&.text || "Unknown Title",
        album_artists(release_id),
        parse_first(release, './/mb:first-release-date').text,
        release_songs(release)
      ]
    end

    ### Processor Helpers

    def title(song_id)
      node = request('recording', song_id)
      parse_item(node, '//mb:title').text
    end

    def cover(release_id)
      result = cover_request(release_id)
      return if result.nil?
      path = Rails.root.join(COVER_PATH, "#{release_id}.jpg")
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, result)
    end

    def album_artists(release_id)
      node = sub_request('release', release_id, 'artist-credits')
      map_ids(node, 'artist')
    end

    # A single album may have several releases which might be slightly different
    #   ex a deluxe version may have a few extra songs
    # Primarily used during the matching stage
    def album_releases(album_id)
      node = linked_request('release', album_id, 'recording')
      node.xpath('//mb:release', NS).map do |cur|
        [
          cur['id'],
          *%w[title status date barcode].map do |data|
            parse_first(cur, "./mb:#{data}").text
          end
        ]
      end
    end

    # Used for getting track numbers, requires the specific album release
    def release_songs(release)
      medium = parse_first(release, '//mb:medium')
      track_num = 0
      medium.xpath('.//mb:recording', NS).map do |cur|
        track_num += 1
        [
          cur['id'],
          track_num,
          parse_item(cur, './/mb:title').text
        ]
      end
    end

    # Primary source of artist data, combining id and data requests saves API requests
    # artistID, artistType, artistName, artistCountry, artistBegin
    def song_artists(song_id)
      node = linked_request('artist', song_id, 'recording')
      node.xpath('//mb:artist', NS).map do |cur|
        [
          cur['id'],
          cur['type'],
          *%w[name country begin].map do |data|
            parse_first(cur, ".//mb:#{data}")&.text || ""
          end,
        ]
      end
    end
  end

end