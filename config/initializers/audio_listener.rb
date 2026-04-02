Rails.application.config.after_initialize do
  require_dependency Rails.root.join("lib", "watcher", "audio_listener")

  begin
    if ActiveRecord::Base.connection.table_exists?('system_settings')
      saved_path = SystemSetting.find_by(key: 'incoming_path')&.value
    end

    watch_path = saved_path

    unless Rails.env.test?
      Watcher::AudioListener.start(watch_path)
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    puts "Database not ready yet. Listener will start on first UI interaction."
  end
end