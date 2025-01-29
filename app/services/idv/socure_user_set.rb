# frozen_string_literal: true

module Idv
  class SocureUserSet
    attr_reader :redis_pool

    ADD_USER_SCRIPT = <<~LUA_EOF
      local key = KEYS[1]
      local user_uuid = ARGV[1]
      local max_allowed_users = tonumber(ARGV[2])

      local number_of_socure_users = redis.call('SCARD', key)
      if number_of_socure_users >= max_allowed_users then
        return false
      end
      redis.call('SADD', key, user_uuid)
      return true
    LUA_EOF

    ADD_USER_SCRIPT_SHA1 = Digest::SHA1.hexdigest(ADD_USER_SCRIPT).freeze

    def initialize(redis_pool: REDIS_POOL)
      @redis_pool = redis_pool
    end

    def add_user!(user_uuid:)
      script_args = [user_uuid.to_s, IdentityConfig.store.doc_auth_socure_max_allowed_users.to_i]
      redis_pool.with do |client|
        begin
          return client.evalsha(ADD_USER_SCRIPT_SHA1, [key], script_args)
        rescue Redis::CommandError => error
          raise error unless error.message.start_with?('NOSCRIPT')
          return client.eval(ADD_USER_SCRIPT, [key], script_args)
        end
      end
    end

    def count
      redis_pool.with do |client|
        client.scard(key)
      end
    end

    def maxed_users?
      count >= IdentityConfig.store.doc_auth_socure_max_allowed_users
    end

    private

    def key
      'idv:socure:users'
    end
  end
end
