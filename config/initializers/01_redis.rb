# frozen_string_literal: true

# This file is renamed to 01_redis.rb so that this file is loaded before rack_attack.rb.
# This is done because rack_attack.rb needs to reference the Throttle pool defined here.
REDIS_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_url)
end

REDIS_THROTTLE_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_throttle_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_throttle_url)
end
