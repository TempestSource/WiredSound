namespace :watcher do
  desc "Start the Audio File Listener"
  task start: :environment do
    require Rails.root.join('lib', 'watcher', 'audio_listener')
    AudioListener.start
  end
end