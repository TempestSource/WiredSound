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

ActiveRecord::Schema[8.1].define(version: 2026_02_20_231030) do
  create_table "album_artists", primary_key: ["albumID", "artistID"], charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "albumID", null: false
    t.string "artistID", null: false
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
  end

  create_table "artist_info", primary_key: "artirstID", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.date "artistBegin"
    t.string "artistCountry"
    t.string "artistName", null: false
    t.string "artistType"
  end

  create_table "hash_match", primary_key: "hash", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "songID", null: false
  end

  create_table "song_artists", primary_key: ["songID", "artistID"], charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "artistID", null: false
    t.string "songID", null: false
  end

  create_table "song_info", primary_key: "songID", id: :string, charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "releaseID", null: false
    t.string "songName", null: false
    t.integer "trackNumber"
  end
end
