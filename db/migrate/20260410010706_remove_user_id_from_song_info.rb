class RemoveUserIdFromSongInfo < ActiveRecord::Migration[7.1]
  def change
    remove_column :song_info, :user_id, :bigint
  end
end