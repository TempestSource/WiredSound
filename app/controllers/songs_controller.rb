require "ostruct"

class SongsController < ApplicationController
  # before_action :set_song, only: [:show, :link, :update, :destroy]
  before_action :set_song, only: [:show, :link, :update, :destroy], unless: -> { params[:id] == 'new' }
  def index
    @recognized_songs = SongInfo.includes(:artist_infos, album_release: :album_info)

    if params[:query].present?
      search_query = "%#{params[:query]}%"
      @recognized_songs = @recognized_songs.left_joins(:artist_infos, album_release: :album_info)
                                           .where("song_info.songName LIKE ? OR
                                                   artist_info.artistName LIKE ? OR
                                                   album_info.albumName LIKE ?",
                                                  search_query, search_query, search_query).distinct
    end

    @recognized_songs = case params[:sort]
                        when "title"
                          @recognized_songs.order(:songName)
                        when "artist"
                          @recognized_songs.joins(:artist_infos).order('artist_info.artistName')
                        when "album"
                          @recognized_songs.joins(album_release: :album_info).order('album_info.albumName')
                        else
                          @recognized_songs.order(:songName)
                        end

    unrecognized_path = Rails.root.join("storage", "unrecognized", "*.mp3")
    @unrecognized_files = Dir.glob(unrecognized_path).map do |file_path|
      filename = File.basename(file_path, ".mp3")
      OpenStruct.new(songName: filename, songID: nil, is_local: true)
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

      artist = ArtistInfo.find_or_create_by!(artistID: mb_artist_id) do |a|
        a.artistName = mb_artist_name
      end

      album = AlbumInfo.find_or_create_by!(albumID: "alb_#{mb_song_id}") do |a|
        a.albumName = "#{mb_title} - Single"
      end

      release = AlbumRelease.find_or_create_by!(releaseID: "rel_#{mb_song_id}") do |r|
        r.albumID = album.albumID
        r.releaseName = "#{mb_title} - MusicBrainz Single"
      end


      @song = SongInfo.find_by(songName: old_filename) || SongInfo.new

      @song.assign_attributes(
        songID: mb_song_id,
        songName: mb_title,
        releaseID: release.releaseID
      )

      if @song.save
        SongArtist.find_or_create_by!(songID: @song.songID, artistID: artist.artistID)

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
    @song = SongInfo.find_by!(songID: params[:id])

    library_path = Rails.root.join("storage", "library", "#{@song.songName}.mp3")
    unrecognized_path = Rails.root.join("storage", "unrecognized", "#{@song.songName}.mp3")

    File.delete(library_path) if File.exist?(library_path)
    File.delete(unrecognized_path) if File.exist?(unrecognized_path)


    flash[:notice] = "The local audio file was deleted, but the database record was kept."
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