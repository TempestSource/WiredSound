require "ostruct"

class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:show, :link, :update, :destroy], unless: -> { params[:id] == 'new' }
  def index
    library_path = Rails.root.join("storage", "library", "*.mp3")
    unrecognized_path = Rails.root.join("storage", "unrecognized", "*.mp3")

    @songs = (Dir.glob(library_path) + Dir.glob(unrecognized_path)).map do |file_path|
      filename = File.basename(file_path, ".mp3")

      OpenStruct.new(
        songName: filename,
        songID: 0,
        is_local: true
      )
    end
  end

  def show
    if params[:filename].present?
      @song = OpenStruct.new(
        songName: params[:filename],
        songID: "Unlinked File",
        is_local: true
      )
    else
      @song = SongInfo.find(params[:id])
    end
  end

  def new
    @song = SongInfo.new(songName: "unlinked")
    @song.save
    redirect_to songs_path
  end

  def link
  end

  def update
    if @song.update(song_params)
      redirect_to @song
    else
      render :link, status: :unprocessable_entity
    end
  end

  def create
    mbid = params[:mbid].strip
    old_filename = params[:filename]

    begin

      mb = Metadata.new

      song_data = mb.process_song(mbid)
      mb_song_id = song_data[0]
      mb_title = song_data[1]
      mb_artists = song_data[2] # This is an array of artist data arrays

      # 2. Extract the primary artist data
      first_artist = mb_artists.first
      mb_artist_id = first_artist[0]
      mb_artist_name = first_artist[2]

      # 3. Find or Create Artist
      artist = ArtistInfo.find_or_create_by!(artistID: mb_artist_id) do |a|
        a.artistName = mb_artist_name
      end

      # 4. Find or Create a generic Release to satisfy schema relationships
      release = AlbumRelease.find_or_create_by!(releaseID: "rel_#{mb_song_id}") do |r|
        r.albumID = "alb_#{mb_song_id}"
        r.releaseName = "#{mb_title} - MusicBrainz Single"
      end

      # 5. Link the data to the existing SongInfo record created by the audio_processor
      # If the processor bypassed DB creation, we create a new one.
      @song = SongInfo.find_by(songName: old_filename) || SongInfo.new(user_id: 1)

      @song.assign_attributes(
        songID: mb_song_id,
        songName: mb_title,
        releaseID: release.releaseID
      )

      if @song.save
        # 6. Create the Many-to-Many Artist Link
        SongArtist.find_or_create_by!(songID: @song.songID, artistID: artist.artistID)

        # 7. Physically rename and move the file
        old_path = Rails.root.join("storage", "unrecognized", "#{old_filename}.mp3")
        new_path = Rails.root.join("storage", "library", "#{mb_title}.mp3")

        if File.exist?(old_path)
          File.rename(old_path, new_path)
        end

        flash[:notice] = "Successfully linked '#{mb_title}' using MusicBrainz!"
        redirect_to root_path
      else
        flash[:alert] = "Failed to save database records."
        render :link, status: :unprocessable_entity
      end

    rescue => e
      flash[:alert] = "API Error: Could not fetch data from MusicBrainz. (#{e.message})"
      redirect_to root_path
    end
  end
  def destroy
    file_path = Rails.root.join("storage", "library", "#{@song.songName}.mp3")

    if File.exist?(file_path)
      File.delete(file_path)
      flash[:notice] = "The local audio file was deleted, but the database record was kept."
    else
      flash[:alert] = "Database record kept, but the physical file was not found on the server."
    end
    redirect_to songs_path
  end

  private

  def set_song
    @song = SongInfo.find(params[:id])
  end

  def song_params
    params.expect(song_info: [:songName])
  end
end