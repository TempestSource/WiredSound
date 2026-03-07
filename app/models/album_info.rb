class AlbumInfo < ApplicationRecord
  self.table_name = "album_info"
  self.primary_key = "albumID"

  has_many :song_infos, foreign_key: "albumID"
  has_many :album_releases, foreign_key: "albumID"

  has_many :album_artists, foreign_key: "albumID"
  has_many :artist_infos, through: :album_artists
end