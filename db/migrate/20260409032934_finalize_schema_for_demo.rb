class FinalizeSchemaForDemo < ActiveRecord::Migration[8.1]
  def change
    unless table_exists?(:settings)
      create_table :settings do |t|
        t.string :key, null: false, index: { unique: true }
        t.string :value
        t.timestamps
      end
    end

    rename_table :song_infos, :song_info if table_exists?(:song_infos)
    rename_table :hash_matches, :hash_match if table_exists?(:hash_matches)

    if table_exists?(:hash_match) && column_exists?(:hash_match, :hash)
      rename_column :hash_match, :hash, :raw_hash
    end

    if table_exists?(:song_info) && !column_exists?(:song_info, :user_id)
      add_column :song_info, :user_id, :bigint
    end

    up_only do
      unless ActiveRecord::Base.connection.execute("SELECT 1 FROM settings WHERE `key` = 'incoming_path'").any?
        execute "INSERT INTO settings (`key`, `value`, created_at, updated_at) VALUES ('incoming_path', 'storage/incoming', NOW(), NOW())"
      end
      unless ActiveRecord::Base.connection.execute("SELECT 1 FROM settings WHERE `key` = 'library_path'").any?
        execute "INSERT INTO settings (`key`, `value`, created_at, updated_at) VALUES ('library_path', 'storage/library', NOW(), NOW())"
      end
    end
  end
end