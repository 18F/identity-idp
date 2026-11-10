# frozen_string_literal: true

module TokenExchange
  # Short-lived encrypted record keyed by an OIDC authorization code and living exactly as long
  # as the code: the actor return log that the code's subject token originates from and, for a
  # client whose tokens are key-bound (RFC 9449), the RFC 7638 thumbprint of the key the
  # authorization request named, so the code can be redeemed only with a proof from that key.
  # The raw authorization code is never stored, and nothing here outlives the code.
  ActorHandoff = Struct.new(:id, :actor_return_log_id, :dpop_jkt, keyword_init: true) do
    def self.redis_key_prefix
      'token-exchange-actor-handoff'
    end

    def self.load(code)
      EncryptedRedisStructStorage.load(digest(code), type: self)
    end

    def self.store(code:, actor_return_log_id:, expires_in:, dpop_jkt: nil)
      handoff = new(id: digest(code), actor_return_log_id:, dpop_jkt:)
      EncryptedRedisStructStorage.store(handoff, expires_in:)
    end

    def self.digest(code)
      Digest::SHA256.hexdigest(code.to_s)
    end
  end
end
