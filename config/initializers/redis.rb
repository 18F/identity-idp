REDIS_POOL = ConnectionPool.new(size: 10) do
  Redis::Namespace.new(
    'redis-pool',
    redis: Redis.new(url: IdentityConfig.store.redis_url),
  )
end

REDIS_THROTTLE_POOL = ConnectionPool.new(size: 5) do
  Redis::Namespace.new(
    'throttle',
    redis: Redis.new(url: IdentityConfig.store.redis_throttle_url),
  )
end
