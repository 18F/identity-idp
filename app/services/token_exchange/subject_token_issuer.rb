# frozen_string_literal: true

module TokenExchange
  class SubjectTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    # @param dpop_jkt [String, nil] RFC 7638 thumbprint of the key the subject token is bound to
    #   (RFC 9449), carried from the authorization code it is issued for; nil for a bearer token
    # @param resource [String, nil] the resource the sign-in named; the token can be exchanged only
    #   for it
    # @param scope [String, nil] scope granted at the sign-in the token comes from; defaults to
    #   the identity's, which is that sign-in's only while its code is being redeemed
    # @param ial [Integer, nil] as for scope
    def self.issue(identity:, resource:, actor_return_log_id: nil, dpop_jkt: nil, scope: nil,
                   ial: nil)
      new(identity:, resource:, actor_return_log_id:, dpop_jkt:, scope:, ial:).issue
    end

    def initialize(identity:, resource:, actor_return_log_id:, dpop_jkt:, scope:, ial:)
      @identity = identity
      @actor_return_log_id = actor_return_log_id
      @dpop_jkt = dpop_jkt
      @resource = resource
      @scope = scope || identity.scope
      @ial = ial || identity.ial
    end

    def issue
      token = SecureRandom.urlsafe_base64(32)
      expires_in = IdentityConfig.store.token_exchange_subject_token_expires_in
      subject_token = SubjectToken.new(
        id: SubjectToken.digest(token),
        identity_uuid: identity.uuid,
        actor_issuer: identity.service_provider,
        scope:,
        ial:,
        actor_return_log_id:,
        dpop_jkt:,
        issued_at: Time.zone.now.to_i,
        resource:,
      )

      EncryptedRedisStructStorage.store(subject_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :identity, :actor_return_log_id, :dpop_jkt, :resource, :scope, :ial
  end
end
