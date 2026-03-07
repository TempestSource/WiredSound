class AlbumRelease < ApplicationRecord
  self.table_name = "album_releases"
  self.primary_key = "releaseID"

  belongs_to :album_info, foreign_key: "albumID"
end