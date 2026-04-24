class User < ApplicationRecord

  has_secure_password

  validates :username, uniqueness: true, length: { minimum: 4, maximum: 20 }
  validates :password, length: {minimum: 12}

  def self.authenticate(username, password)
    user = User.find_by(username: username)
    return nil unless user

    user.authenticate(password)
  end
end
