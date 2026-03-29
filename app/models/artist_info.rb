class ArtistInfo < ApplicationRecord
  self.table_name = "artist_info"
  self.primary_key = "artistID"

  has_many :song_artists, foreign_key: "artistID"
  has_many :song_infos, through: :song_artists

  has_many :album_artists, foreign_key: "artistID"
  has_many :album_infos, through: :album_artists
end