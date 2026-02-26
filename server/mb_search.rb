# frozen_string_literal: true

require 'httparty'
class MBSearch

  # Metadata Source URL & User Agent
  def initialize
    @url = 'https://musicbrainz.org/ws/2/'
    @user_agent = 'WiredSound/0.1'
  end

  # arg1: entity, arg2: mbid, arg3: subsearch
  def request(*args)
    if args.size == 2
      HTTParty.get(@url + "#{args[0]}/#{args[1]}",
                   headers: { 'User-Agent' => @user_agent })
    elsif args.size == 3
      HTTParty.get(@url + "#{args[0]}/#{args[1]}?inc=#{args[2]}",
                   headers: { 'User-Agent' => @user_agent })
    end
  end

  def song(mbid)
    request('recording', mbid)
  end

  def artist(mbid)
    request('artist', mbid)
  end

  def album(mbid)
    request('release', mbid)
  end

  def album_songs(mbid)
    request('release', mbid, 'recordings')
  end
end
