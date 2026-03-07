class AlbumArtist < ApplicationRecord
  self.table_name = "album_artists"

  belongs_to :album_info, foreign_key: "albumID"
  belongs_to :artist_info, foreign_key: "artistID"
end