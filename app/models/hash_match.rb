class HashMatch < ApplicationRecord
  self.table_name = "hash_match"

  belongs_to :song_info, foreign_key: "songID", primary_key: "songID"

  validates :raw_hash, presence: true, length: { is: 32 }, uniqueness: true
  validates :songID, presence: true
end