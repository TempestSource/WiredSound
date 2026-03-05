class SongInfo < ApplicationRecord
  self.table_name = "song_info"
  self.primary_key = "songID"

  belongs_to :artist_info, foreign_key: "artistID", optional: true
  belongs_to :album_info, foreign_key: "albumID", optional: true
end