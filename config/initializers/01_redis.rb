# frozen_string_literal: true

# This file is renamed to 01_redis.rb so that this file is loaded before rack_attack.rb.
# This is done because rack_attack.rb needs to reference the Throttle pool defined here.
REDIS_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_url)
end.freeze

REDIS_THROTTLE_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_throttle_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_throttle_url)
end.freeze

REDIS_ATTEMPTS_API_POOL =
  ConnectionPool.new(size: IdentityConfig.store.redis_attempts_api_pool_size) do
    Redis.new(url: IdentityConfig.store.redis_attempts_api_url)
  end.freeze

REDIS_SECURED_DATA_API_POOL =
  ConnectionPool.new(size: IdentityConfig.store.redis_secured_data_api_pool_size) do
    Redis.new(url: IdentityConfig.store.redis_secured_data_api_url)
  end.freeze
