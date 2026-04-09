class HashMatch < ApplicationRecord
  self.table_name = "hash_match"
  self.ignored_columns = ["hash"]
  belongs_to :song_info, foreign_key: "songID", primary_key: "songID"

  def self.save_hash(raw_hash, song_id)
    ActiveRecord::Base.connection.insert(
      "INSERT INTO hash_match (raw_hash, songID) VALUES ('#{raw_hash}', '#{song_id}')"
    )
  end
end