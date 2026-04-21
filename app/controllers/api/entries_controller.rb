module Api
  class EntriesController < ApiController
    def create
      unless entry_params[:raw_hash].present? && entry_params[:songID].present? && entry_params[:releaseID].present?
        return render_error("Requires raw_hash, songID and releaseID", :bad_request)
      end
      unless entry_params[:raw_hash].to_s.length == 32
        return render_error("Invalid hash", :bad_request)
      end

      if HashMatch.exists?(raw_hash: entry_params[:raw_hash])
        return render_error("Duplicate hash, please use update to refresh", :bad_request)
      end

      Dbupdater.db_add(entry_params[:raw_hash], entry_params[:songID], entry_params[:releaseID])

      song = SongInfo.find_by_songID(entry_params[:songID])
      return render json: song, status: :ok

    end

    private

    def entry_params
      params.permit(:raw_hash, :songID, :releaseID)
    end
  end
end