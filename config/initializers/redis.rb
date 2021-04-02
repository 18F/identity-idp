env = AppConfig.env
ttl = env.service_provider_request_ttl_hours || ServiceProviderRequestProxy::DEFAULT_TTL_HOURS
REDIS_POOL = ConnectionPool.new(size: 10) do
  Readthis::Cache.new(
    expires_in: ttl.to_i.hours.to_i,
    redis: { url: IdentityConfig.store.redis_url, driver: :hiredis },
  )
end
