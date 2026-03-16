class AlbumRelease < ApplicationRecord
  self.table_name = "album_releases"
  self.primary_key = "releaseID"

  belongs_to :album_info, foreign_key: "albumID", primary_key: "albumID"
  has_many :song_infos, foreign_key: "releaseID", primary_key: "releaseID"
end
