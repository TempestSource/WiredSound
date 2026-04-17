class TokenRefresh
  TOKEN_PREFIX = 'refresh_token'.freeze
  USER_PREFIX = 'user_tokens'.freeze

  class << self
    def create_token(username, user_agent = nil)
      token = JwtAuth.create_token_refresh(username)
      payload = JwtAuth.decode_token(token)

      store_token(
        jti: payload[:jti],
        username: username,
        user_agent: user_agent,
        expires_at: Time.at(payload[:exp])
      )

      user_token_add(username, payload[:jti])

      {
        token: token,
        jti: payload[:jti]
      }
    end

    def store_token(jti:, username:, user_agent:, expires_at:)
      token_key = "#{TOKEN_PREFIX}#{jti}"
      ttl = (expires_at - Time.current).to_i

      redis.multi do |cur|
        cur.hset(
          token_key,
          'username', username,
          'user_agent', user_agent,
          'revoked', 'false',
          'created_at', Time.current.iso8601
        )
        multi.expire(token_key, ttl)
      end
    end

    def get_token(jti)
      token_key = "#{TOKEN_PREFIX}#{jti}"
      token = redis.hgetall(token_key)
      {
        username: token['username'],
        user_agent: token['user_agent'],
        revoked: token['revoked'] == true,
        created_at: token['created_at']
      }
    end

    def user_token_add(username, jti)
      user_key = "#{USER_PREFIX}#{username}"
      redis.sadd(user_key, jti)
    end

    def user_token_del(username, jti)
      user_key = "#{USER_PREFIX}#{username}"
      redis.srem(user_key, jti)
    end

    def revoke(jti)
      token_key = "#{TOKEN_PREFIX}#{jti}"

      redis.multi do |cur|
        cur.hset(token_key, 'revoked', 'true')
        cur.expire(token_key, 0)
      end
    end

    def revoke_user(username)
      user_key = "#{USER_PREFIX}#{username}"
      jti_set = redis.smembers(user_key)

      jti_set.each do |jti|
        revoke_user(jti)
      end
      redis.del(username)
    end

    def validate(token)
      payload = JwtAuth.decode_token(token)
      token_data = get_token(payload[:jti])

      return nil unless token_data
      return nil if token_data[:revoked]

      token_data
    rescue JWT::DecodeError
      nil
    end

    def rotate(token)
      payload = JwtAuth.decode_token(token)
      token_data = get_token(payload[:jti])

      if token_data[:revoked]
        revoke_user(token_data[:username])
        raise SecurityError, 'Expired token used'
      end

      username = token_data[:username]

      revoke(payload[:jti])
      revoke_user(payload[:jti])

      new_access_token = JwtAuth.create_token_access(username)
      new_refresh_token = JwtAuth.create_token_refresh(username)
      payload = JwtAuth.decode_token(new_refresh_token)

      store_token(
        jti: payload[:jti],
        username: username,
        user_agent: payload[:user_agent],
        expires_at: Time.at(payload[:exp])
      )
      user_token_add(username, payload[:jti])

      {
        access_token: new_access_token,
        refresh_token: new_refresh_token
      }
    end

    def redis
      @redis ||= Redis.new(url: ENV['REDIS_URL'])
    end

  end
end