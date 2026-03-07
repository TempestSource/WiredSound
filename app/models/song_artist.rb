class SongArtist < ApplicationRecord
  self.table_name = "song_artists"

  belongs_to :song_info, foreign_key: "songID"
  belongs_to :artist_info, foreign_key: "artistID"
end