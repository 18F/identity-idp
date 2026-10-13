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
  end
end
