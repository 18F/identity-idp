# frozen_string_literal: true

module TokenExchange
  SubjectToken = Struct.new(
    :id,
    :identity_uuid,
    :broker_issuer,
    :scope,
    :ial,
    :actor_return_log_id,
    :dpop_jkt,
    :issued_at,
    keyword_init: true,
  ) do
    def self.redis_key_prefix
      'token-exchange-subject-token'
    end

    def self.load(token)
      EncryptedRedisStructStorage.load(digest(token), type: self)
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end
  end
end
