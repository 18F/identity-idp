# frozen_string_literal: true

module TokenExchange
  # Short-lived encrypted bridge from an OIDC authorization code to the exact actor return log
  # that the code's subject token originated from. The raw authorization code is never stored.
  ActorHandoff = Struct.new(:id, :actor_return_log_id, keyword_init: true) do
    def self.redis_key_prefix
      'token-exchange-actor-handoff'
    end

    def self.load(code)
      EncryptedRedisStructStorage.load(digest(code), type: self)
    end

    def self.store(code:, actor_return_log_id:, expires_in:)
      handoff = new(id: digest(code), actor_return_log_id:)
      EncryptedRedisStructStorage.store(handoff, expires_in:)
    end

    def self.digest(code)
      Digest::SHA256.hexdigest(code.to_s)
    end
  end
end
