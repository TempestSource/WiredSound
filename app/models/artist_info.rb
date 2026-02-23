class ArtistInfo < ApplicationRecord
  self.table_name = "artist_info"
  self.primary_key = "artistID"

  has_many :song_infos, foreign_key: "artistID"
  has_many :album_infos, foreign_key: "artistID"
end