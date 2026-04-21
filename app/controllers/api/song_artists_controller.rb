module Api
  class SongArtistsController < ApplicationController
    def index
      response = HTTParty.get("#{AudioProcessor::API_BASE}/songs",
                              headers: { "Authorization" => "Bearer #{session[:token]}" }
      )
      @songs = response.parsed_response if response.success?
    end

    def show
      artists = SongArtist.find(params[:id])
      render json: artists
    end
  end
end