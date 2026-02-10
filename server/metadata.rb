require 'musicbrainz'

MusicBrainz.configure do |mb|
  mb.app_name = "WiredSound"
  mb.app_version = "0.0.1"
  mb.contact = "tempestsource@gmail.com"
end

def get_search_result(title, artist)
  results = MusicBrainz::Recording.search(title, artist)
  results.first
end

def get_song_id(recording)
  recording[:mbid]
end

def get_song_artist(recording)
  recording[:artist]
end

def get_song_title(recording)
  recording[:title]
end