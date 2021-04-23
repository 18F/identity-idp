env = AppConfig.env
REDIS_POOL = ConnectionPool.new(size: 10) do
  Readthis::Cache.new(
    expires_in: IdentityConfig.store.service_provider_request_ttl_hours.hours.to_i,
    redis: { url: IdentityConfig.store.redis_url, driver: :hiredis },
  )
end
