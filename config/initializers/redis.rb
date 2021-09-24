REDIS_POOL = ConnectionPool.new(size: 10) do
  Redis::Namespace.new(
    'redis-pool',
    redis: Redis.new(url: IdentityConfig.store.redis_url),
  )
end
