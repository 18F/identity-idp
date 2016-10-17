class IdentityIdp
  def self.redis
    @_redis ||= Redis.new(url: Figaro.env.redis_url)
  end
end
