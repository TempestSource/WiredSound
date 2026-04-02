require_dependency Rails.root.join("lib", "watcher", "audio_listener")
class SettingsController < ApplicationController
  def show
    @incoming_path = SystemSetting.find_by(key: 'incoming_path')&.value || Rails.root.join('storage', 'incoming_music').to_s
  end

  def update
    new_path = params[:incoming_path]


    unless Dir.exist?(new_path)
      flash[:alert] = "Invalid Directory Path: The directory does not exist or is restricted."
      redirect_to settings_path
      return
    end

    setting = SystemSetting.find_or_initialize_by(key: 'incoming_path')
    setting.value = new_path

    if setting.save
      Watcher::AudioListener.restart(new_path)
      flash[:notice] = "Listener successfully updated to #{new_path}"
    end

    redirect_to settings_path
  end
end