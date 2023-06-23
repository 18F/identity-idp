module Cache
  # Wrapper to simplify and encapsulate access for commonly
  # used cache operations
  class CacheWrapper
    # @param [ActiveSupport::Cache::Store] cache
    def initialize(cache: Rails.cache)
      @cache = cache
    end

    # @param [String] key Cache key
    # @return [Object,nil] Cached value
    def read(key)
      cache.read(key)
    end

    # @param [String] key Cache key
    # @param [Object,nil] entry Cached value
    # @param [Number] expires_at Unix time in milliseconds
    def write(_key, entry, expires_at:)
      cache.write(cache_key, entry, expires_at: expires_at)

      # If using a redis cache we have to manually set the expires_at. This is because we aren't
      # using a dedicated Redis cache and instead are just using our existing Redis server with
      # mixed usage patterns. Without this cache entries don't expire.
      # More at https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html
      cache.try(:redis)&.expireat(cache_key, expires_at.to_i)
    end

    private

    attr_accessor :cache
  end
end
