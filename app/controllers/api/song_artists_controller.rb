module Api
  class SongArtistsController < ApplicationController
    def index
      response = HTTParty.get("#{AudioProcessor::API_BASE}/songs",
                              headers: { "Authorization" => "Bearer #{session[:token]}" }
      )

      if response.success?
        @songs = response.parsed_response
        render json: @songs
      else
        render json: { error: "Could not fetch songs" }, status: :service_unavailable
      end
    end
  end
end