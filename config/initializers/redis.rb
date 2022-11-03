REDIS_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_pool_size) do
  Redis::Namespace.new(
    'redis-pool',
    redis: Redis.new(url: IdentityConfig.store.redis_url),
  )
end

REDIS_THROTTLE_POOL = ConnectionPool.new(size: IdentityConfig.store.redis_throttle_pool_size) do
  Redis::Namespace.new(
    'throttle',
    redis: Redis.new(url: IdentityConfig.store.redis_throttle_url),
  )
end
