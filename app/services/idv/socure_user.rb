# frozen_string_literal: true

module Idv
  class SocureUser
    attr_reader :redis_pool

    def initialize(redis_pool: REDIS_POOL)
      @redis_pool = redis_pool
    end

    def add_user!(user_uuid:)
      return if maxed_users?

      redis_pool.with do |client|
        client.sadd(key, user_uuid)
      end
    end

    def count
      redis_pool.with do |client|
        client.scard(key)
      end
    end

    private

    def maxed_users?
      count >= IdentityConfig.store.doc_auth_socure_max_allowed_users
    end

    def key
      'idv:socure:users'
    end
  end
end
