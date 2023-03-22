REDIS_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_url)
end

REDIS_THROTTLE_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_throttle_pool_size) do
  Redis.new(url: IdentityConfig.store.redis_throttle_url)
end

REDIS_THROTTLE_ALTERNATE_POOL =
  if IdentityConfig.store.redis_throttle_alternate_url
    ConnectionPool.new(size: IdentityConfig.store.redis_throttle_pool_size) do
      Redis.new(url: IdentityConfig.store.redis_throttle_alternate_url)
    end
  end
