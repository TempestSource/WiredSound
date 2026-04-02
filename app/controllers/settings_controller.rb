require_dependency Rails.root.join("lib", "watcher", "audio_listener")
class SettingsController < ApplicationController
  def show
    @incoming_path = SystemSetting.find_by(key: 'incoming_path')&.value || Rails.root.join('storage', 'incoming_music').to_s
  end

  def update
    new_path = params[:incoming_path]

    puts "Checking if path exists in Docker: #{new_path}"

    if Dir.exist?(new_path)
      setting = SystemSetting.find_or_create_by(key: 'incoming_path')
      setting.update(value: new_path)
      Watcher::AudioListener.restart(new_path)
      redirect_to settings_path, notice: "Listener reinitialized to: #{new_path}"
    else
      puts "Current accessible directories: #{Dir.entries('/')}"
      redirect_to settings_path, alert: "Directory '#{new_path}' not found in Docker container."
    end
  end
end