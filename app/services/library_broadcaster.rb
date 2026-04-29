class LibraryBroadcaster
  def self.broadcast(song_id:, song_name:, is_recognized:)
    ui_song = UiSong.build_from_api(
      { "songID" => song_id, "songName" => song_name },
      song_id,
      [{ "artistName" => is_recognized ? "Identifying..." : "Unknown Artist" }],
      { "albumName" => is_recognized ? "Identifying..." : "Unknown Album" }
    )

    if is_recognized
      Turbo::StreamsChannel.broadcast_prepend_to(
        "songs", target: "songs", partial: "songs/song", locals: { song: ui_song }
      )
      broadcast_notification("success", "Successfully added: #{song_name}")
      puts "Broadcasted #{song_name} to the Library UI."
    else
      Turbo::StreamsChannel.broadcast_prepend_to(
        "unrecognized_songs",
        target: "unrecognized_songs",
        partial: "songs/unrecognized_song",
        locals: { song: ui_song }
      )
      broadcast_notification("info", "New unrecognized file: #{song_name}")
      puts "Broadcasted #{song_name} to the Unrecognized UI."
    end

    ui_song
  end

  def self.broadcast_notification(type, message)
    Turbo::StreamsChannel.broadcast_append_to(
      "notifications_channel",
      target: "flash-notifications",
      partial: "shared/notification",
      locals: { type: type, message: message }
    )
  end
end