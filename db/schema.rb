# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_09_032934) do
  create_table "album_artists", primary_key: ["albumID", "artistID"], charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "albumID", null: false
    t.string "artistID", null: false
    t.index ["artistID"], name: "fk_album_artists_artist"
  end

  create_table "album_info", primary_key: "albumID", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "albumName", null: false
    t.string "albumType"
    t.string "coverPath"
    t.date "releaseDate"
  end

  create_table "album_releases", primary_key: ["releaseID", "albumID"], charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "albumID", null: false
    t.string "releaseID", null: false
    t.string "releaseName"
    t.index ["albumID"], name: "fk_album_releases_album"
  end

  create_table "artist_info", primary_key: "artistID", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.date "artistBegin"
    t.string "artistCountry"
    t.string "artistName", null: false
    t.string "artistType"
  end

  create_table "hash_match", primary_key: "raw_hash", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "songID", null: false
    t.index ["songID"], name: "fk_hash_match_song"
  end

  create_table "settings", charset: "utf8mb4", collation: "utf8mb4_uca1400_as_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "song_artists", primary_key: ["songID", "artistID"], charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "artistID", null: false
    t.string "songID", null: false
    t.index ["artistID"], name: "fk_song_artists_artist"
  end

  create_table "song_info", primary_key: "songID", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "releaseID", null: false
    t.string "songName", null: false
    t.integer "trackNumber"
    t.bigint "user_id"
    t.index ["releaseID"], name: "fk_song_info_release"
  end

  create_table "system_settings", charset: "utf8mb4", collation: "utf8mb4_uca1400_as_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.datetime "updated_at", null: false
    t.string "value"
  end

  add_foreign_key "album_artists", "album_info", column: "albumID", primary_key: "albumID", name: "fk_album_artists_album", on_update: :cascade, on_delete: :cascade
  add_foreign_key "album_artists", "artist_info", column: "artistID", primary_key: "artistID", name: "fk_album_artists_artist", on_update: :cascade, on_delete: :cascade
  add_foreign_key "album_releases", "album_info", column: "albumID", primary_key: "albumID", name: "fk_album_releases_album", on_update: :cascade, on_delete: :cascade
  add_foreign_key "hash_match", "song_info", column: "songID", primary_key: "songID", name: "fk_hash_match_song", on_update: :cascade, on_delete: :cascade
  add_foreign_key "song_artists", "artist_info", column: "artistID", primary_key: "artistID", name: "fk_song_artists_artist", on_update: :cascade, on_delete: :cascade
  add_foreign_key "song_artists", "song_info", column: "songID", primary_key: "songID", name: "1", on_update: :cascade, on_delete: :cascade
  add_foreign_key "song_info", "album_releases", column: "releaseID", primary_key: "releaseID", name: "fk_song_info_release", on_update: :cascade, on_delete: :cascade
    t.bigint "user_id", null: false
end
