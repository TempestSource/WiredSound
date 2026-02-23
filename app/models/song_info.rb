class SongInfo < ApplicationRecord
  self.table_name = "song_info"
  self.primary_key = "songID"


  has_many :hash_matches, foreign_key: "songID"

  belongs_to :album_info, foreign_key: "albumID"
  belongs_to :artist_info, foreign_key: "artistID"
end