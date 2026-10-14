# frozen_string_literal: true

module TokenExchange
  AccessToken = Struct.new(
    :id,
    :user_id,
    :identity_uuid,
    :broker_issuer,
    :target_issuer,
    :resource,
    :scope,
    :issued_at,
    :expires_at,
    keyword_init: true,
  ) do
    def self.redis_key_prefix
      'token-exchange-access-token'
    end

    def self.load(token)
      EncryptedRedisStructStorage.load(digest(token), type: self)
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    # Redis expires delegated access tokens via TTL, but the TTL and the stored
    # expiration can drift (clock skew between hosts, a configuration change
    # between write and read). Assert the stored expiration explicitly so a
    # logically expired token is never reported as active.
    def expired?(now: Time.zone.now)
      return true if expires_at.blank?

      expires_at.to_i <= now.to_i
    end

    def active?(now: Time.zone.now)
      !expired?(now:)
    end
  end
end
