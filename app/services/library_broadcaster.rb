# app/services/library_broadcaster.rb
class LibraryBroadcaster
  def self.broadcast(song_id:, song_name:, is_recognized:)

    # 1. Use our new PORO instead of a hacked OpenStruct
    ui_song = UiSong.build_from_api(
      { "songID" => song_id, "songName" => song_name },
      song_id,
      [{ "artistName" => is_recognized ? "Identifying..." : "Unknown Artist" }],
      { "albumName" => is_recognized ? "Identifying..." : "Unknown Album" }
    )

    # 2. Push the update to the user's screen
    if is_recognized
      Turbo::StreamsChannel.broadcast_prepend_to(
        "songs", target: "songs", partial: "songs/song", locals: { song: ui_song }
      )
      puts "Broadcasted #{song_name} to the Library UI."
    else
      Turbo::StreamsChannel.broadcast_prepend_to(
        "unrecognized_songs", target: "unrecognized_songs", partial: "songs/song", locals: { song: ui_song }
      )
      puts "Broadcasted #{song_name} to the Unrecognized UI."
    end

    ui_song
  end
end