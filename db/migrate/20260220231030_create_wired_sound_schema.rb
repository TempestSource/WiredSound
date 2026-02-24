class CreateWiredSoundSchema < ActiveRecord::Migration[7.0]
  def change
    create_table :artist_info, id: false do |t|
      t.string :artistID, limit: 255, primary_key: true
      t.string :artistName, limit: 255
    end

    create_table :album_info, id: false do |t|
      t.string :albumID, limit: 255, primary_key: true
      t.string :albumName, limit: 255
      t.string :artistID, limit: 255
      t.string :albumYear, limit: 255
      t.string :coverPath, limit: 255
    end

    create_table :song_info, id: false do |t|
      t.string :songID, limit: 32, primary_key: true
      t.string :albumID, limit: 255
      t.string :artistID, limit: 255
      t.string :songName, limit: 255
    end

    create_table :hash_match, id: false do |t|
      t.string :hashVal, limit: 32, primary_key: true
      t.string :songID, limit: 32
    end
  end
end