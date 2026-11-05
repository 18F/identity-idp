# frozen_string_literal: true

module TokenExchange
  class SubjectTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    # @param dpop_jkt [String, nil] RFC 7638 thumbprint of the key the subject token is bound to
    #   (RFC 9449), carried from the authorization code it is issued for; nil for a bearer token
    def self.issue(identity:, actor_return_log_id: nil, dpop_jkt: nil)
      new(identity:, actor_return_log_id:, dpop_jkt:).issue
    end

    def initialize(identity:, actor_return_log_id:, dpop_jkt:)
      @identity = identity
      @actor_return_log_id = actor_return_log_id
      @dpop_jkt = dpop_jkt
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
        dpop_jkt:,
        issued_at: Time.zone.now.to_i,
      )

      EncryptedRedisStructStorage.store(subject_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :identity, :actor_return_log_id, :dpop_jkt
  end
end
