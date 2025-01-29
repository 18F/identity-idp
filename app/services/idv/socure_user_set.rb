# frozen_string_literal: true

module Idv
  class SocureUserSet
    attr_reader :redis_pool

    def initialize(redis_pool: REDIS_POOL)
      @redis_pool = redis_pool
    end

    def add_user!(user_uuid:)
      redis_pool.with do |client|
        client.eval(
          lua_script,
          [
            key,
            user_uuid,
            IdentityConfig.store.doc_auth_socure_max_allowed_users,
          ],
        )
      end
    end

    def count
      redis_pool.with do |client|
        client.scard(key)
      end
    end

    private

    def key
      'idv:socure:users'
    end

    def lua_script
      <<~LUA_EOF
        local key = ARGV[1]
        local user_uuid = ARGV[2]
        local max_allowed_users = ARGV[3]

        number_of_socure_users = redis.call('SCARD', key)
        if number_of_socure_users >= max_allowed_users then
          return false
        end
        redis.call('SADD', key, user_uuid)
        return true
      LUA_EOF
    end
  end
end
