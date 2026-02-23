require 'digest'

class AudioHasher
  def self.call(file_path)
    return nil unless File.exist?(file_path)

    Digest::MD5.file(file_path).hexdigest
  rescue StandardError => e
    Rails.logger.error("AudioHasher Error: #{e.message}")
    nil
  end
end