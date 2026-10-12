# frozen_string_literal: true

module EncryptedDocStorage
  class RedisStorage
    KEY_PREFIX = 'document-images'

    attr_reader :redis_pool

    def initialize(redis_pool: REDIS_POOL)
      @redis_pool = redis_pool
    end

    # @param [String] encrypted_image AES-GCM payload produced by AesCipherV2
    # @param [String] name storage object name (e.g. "encrypted_images/<uuid>")
    def write_image(encrypted_image:, name:)
      redis_pool.with do |client|
        client.setex(key(name), ttl_seconds, encrypted_image)
      end
    end

    # @return [String, nil] the encrypted payload, or nil if missing or expired
    def read_image(name:)
      value = redis_pool.with { |client| client.get(key(name)) }
      value&.b
    end

    def delete_image(name:)
      redis_pool.with { |client| client.del(key(name)) }
    end

    # @return [Integer, nil] seconds until the object expires, nil if missing
    def ttl(name:)
      remaining = redis_pool.with { |client| client.ttl(key(name)) }
      remaining.negative? ? nil : remaining
    end

    def ttl_seconds
      IdentityConfig.store.document_images_ttl_seconds
    end

    private

    def key(name)
      [KEY_PREFIX, name].join(':')
    end
  end
end
