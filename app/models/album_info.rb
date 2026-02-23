class AlbumInfo < ApplicationRecord
  self.table_name = "album_info"
  self.primary_key = "albumID"

  belongs_to :artist_info, foreign_key: "artistID"
  has_many :song_infos, foreign_key: "albumID"
end