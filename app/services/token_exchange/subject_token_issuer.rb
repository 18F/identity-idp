# frozen_string_literal: true

module TokenExchange
  class SubjectTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    def self.issue(identity:)
      new(identity:).issue
    end

    def initialize(identity:)
      @identity = identity
    end

    def issue
      token = SecureRandom.urlsafe_base64(32)
      expires_in = IdentityConfig.store.token_exchange_subject_token_expires_in
      subject_token = SubjectToken.new(
        id: SubjectToken.digest(token),
        user_id: identity.user_id,
        identity_uuid: identity.uuid,
        broker_issuer: identity.service_provider,
        scope: identity.scope,
        ial: identity.ial,
        issued_at: Time.zone.now.to_i,
      )

      EncryptedRedisStructStorage.store(subject_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :identity
  end
end
