# frozen_string_literal: true

module TokenExchange
  class SubjectTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    def self.issue(identity:, actor_return_log_id: nil)
      new(identity:, actor_return_log_id:).issue
    end

    def initialize(identity:, actor_return_log_id:)
      @identity = identity
      @actor_return_log_id = actor_return_log_id
    end

    def issue
      token = SecureRandom.urlsafe_base64(32)
      expires_in = IdentityConfig.store.token_exchange_subject_token_expires_in
      subject_token = SubjectToken.new(
        id: SubjectToken.digest(token),
        identity_uuid: identity.uuid,
        broker_issuer: identity.service_provider,
        scope: identity.scope,
        ial: identity.ial,
        actor_return_log_id:,
        issued_at: Time.zone.now.to_i,
      )

      EncryptedRedisStructStorage.store(subject_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :identity, :actor_return_log_id
  end
end
