# app/models/ui_song.rb
require 'ostruct'

class UiSong
  include ActiveModel::Model

  # Define the attributes this object is allowed to have
  attr_accessor :songID, :songName, :trackNumber, :artist_infos, :album_release, :is_local

  # 1. Trick Rails into thinking this is a SongInfo record
  # This makes `<%= render @song %>` look for the `songs/_song.html.erb` partial
  def self.model_name
    ActiveModel::Name.new(self, nil, "SongInfo")
  end

  # 2. Tell Rails how to build DOM IDs (e.g., id="song_123")
  def to_key
    [songID]
  end

  def to_param
    songID
  end

  # Tell Rails this is a "saved" object, not a new one waiting for a form
  def persisted?
    true
  end

  # 3. A clean factory method to absorb the API data
  def self.build_from_api(song_data, fallback_id, artists = [], album = nil)
    prepare_hash = lambda do |raw_data|
      data = raw_data.respond_to?(:attributes) ? raw_data.attributes : raw_data
      # Convert all keys to strings and handle the snake_case to camelCase transition
      data.transform_keys { |k| k.to_s.camelize(:lower) }
    end

    new(
      songID: song_data["songID"] || fallback_id,
      songName: song_data["songName"] || song_data["song_name"],
      trackNumber: song_data["trackNumber"] || song_data["track_number"] || "N/A",

      # Map artists and ensure their keys (like artistName) are camelCased
      artist_infos: Array(artists).map { |a| OpenStruct.new(prepare_hash.call(a)) },

      # Map album and ensure coverPath is available even if the DB says cover_path
      album_release: OpenStruct.new(
        album_info: OpenStruct.new(prepare_hash.call(album || { "albumName" => "Unknown Album" }))
      )
    )
  end
end