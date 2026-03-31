class SongInfo < ApplicationRecord
  self.table_name = "song_infos"
  self.primary_key = "songID"

  belongs_to :album_release, foreign_key: "releaseID", primary_key: "releaseID"

  has_many :song_artists, foreign_key: "songID"
  has_many :artist_infos, through: :song_artists
end