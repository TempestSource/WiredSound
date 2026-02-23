class HashMatch < ApplicationRecord
  self.table_name = "hash_match"

  self.primary_key = "hashVal"

  belongs_to :song_info, foreign_key: "songID"
end