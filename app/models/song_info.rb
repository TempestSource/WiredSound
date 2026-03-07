class SongInfo < ApplicationRecord
  self.table_name = "song_info"
  self.primary_key = "songID"

  has_many :hash_matches, foreign_key: "songID"
  belongs_to :album_info, foreign_key: "albumID"

  has_many :song_artists, foreign_key: "songID"
  has_many :artist_infos, through: :song_artists
end