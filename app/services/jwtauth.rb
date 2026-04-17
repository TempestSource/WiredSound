class JwtAuth
  class << self

    def get_timeout(type)
      if type == 'access'
        ENV['JWT_ACCESS_TIMEOUT', 600].to_i
      elsif type == 'refresh'
        ENV['JWT_REFRESH_TIMEOUT', 604800].to_i
      else
        raise 'Invalid type'
      end
    end

    def secret
      ENV.fetch('JWT_SECRET') do
        raise 'Secret not set'
      end
    end

    def encode_token(payload, expiration)
      token = payload.merge(
        exp: expiration.seconds.from_now.to_i, # When the token expires
        iat: Time.now.to_i, # When the token was issued
        jti: SecureRandom.uuid # Token identifier
      )
      JWT.encode(token, secret)
    end

    def decode_token(token)
      JWT.decode(token, secret).first.with_indifferent_access
    rescue JWT::ExpiredSignature
      raise JWT::DecodeError, 'Expired Token'
    rescue JWT::DecodeError => e
      raise JWT::DecodeError, "Invalid token: #{e.message}"
    end

    def create_token_access(username)
      encode_token({
                     sub: username,
                     type: 'access'
                   }, get_timeout('access'))
    end

    def create_token_refresh(username)
      encode_token({
                     sub: username,
                     type: 'refresh'
                   }, get_timeout('refresh'))
    end

    def create_token_pair(username)
      {
        access_token: create_token_access(username),
        refresh_token: create_token_refresh(username)
      }
    end

  end
end
