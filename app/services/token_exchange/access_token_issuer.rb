# frozen_string_literal: true

module TokenExchange
  class AccessTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, :delegation_id, keyword_init: true)

    def self.issue(subject_token:, target_identity:, target_issuer:, resource:, scope:)
      new(
        subject_token:,
        target_identity:,
        target_issuer:,
        resource:,
        scope:,
      ).issue
    end

    # `target_identity` is the person's identity at the application named in the audience, the
    # `identities` row a direct sign-in there created; the caller has already refused a person
    # without one, so delegation never creates it. Its `uuid` is the token's `sub`.
    def initialize(subject_token:, target_identity:, target_issuer:, resource:, scope:)
      @subject_token = subject_token
      @target_identity = target_identity
      @target_issuer = target_issuer
      @resource = resource
      @scope = scope
    end

    def issue
      expires_in = IdentityConfig.store.token_exchange_access_token_expires_in
      issued_at = Time.zone.now.to_i
      expires_at = issued_at + expires_in
      delegation_id = DelegatedIssuanceLog.generate_delegation_id
      token = jwe(issued_at:, expires_at:)
      access_token = AccessToken.new(
        id: AccessToken.digest(token),
        identity_uuid: target_identity.uuid,
        broker_issuer: subject_token.broker_issuer,
        target_issuer:,
        resource:,
        scope:,
        issued_at:,
        expires_at:,
      )

      DelegatedIssuanceLog.transaction do
        target_return_log = create_target_return_log
        DelegatedIssuanceLog.create!(
          delegation_id:,
          user: target_identity.user,
          actor_return_log_id: subject_token.actor_return_log_id,
          target_return_log:,
          actor_issuer: subject_token.broker_issuer,
          target_issuer:,
          resource:,
          scope:,
          issued_at: Time.zone.at(issued_at),
          expires_at: Time.zone.at(expires_at),
        )
        EncryptedRedisStructStorage.store(access_token, expires_in:)
      end

      IssuedToken.new(token:, expires_in:, delegation_id:)
    end

    private

    attr_reader :subject_token, :target_identity, :target_issuer, :resource, :scope

    def jwe(issued_at:, expires_at:)
      OpenidConnect::JweEncryptor.encrypt(jwt(issued_at:, expires_at:), service_provider: target)
    end

    def jwt(issued_at:, expires_at:)
      JWT.encode(
        payload(issued_at:, expires_at:),
        AppArtifacts.store.oidc_primary_private_key,
        IdTokenBuilder::JWT_SIGNING_ALGORITHM,
        kid: JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid,
      )
    end

    def payload(issued_at:, expires_at:)
      {
        iss: IdentityConfig.store.domain_name,
        sub: target_identity.uuid,
        aud: target_issuer,
        exp: expires_at,
        iat: issued_at,
        scope:,
        act: {
          sub: subject_token.broker_issuer,
        },
        # The level of the identity the token names, as that agency's own sign-in set it; the
        # agency's API reads it from the token instead of asking.
        acr: "#{Saml::Idp::Constants::IAL_AUTHN_CONTEXT_PREFIX}/#{target_identity.ial.to_i}",
      }
    end

    def create_target_return_log
      profile = target_identity.user.active_profile

      SpReturnLog.create!(
        request_id: SecureRandom.uuid,
        user: target_identity.user,
        billable: true,
        ial: profile ? 2 : 1,
        issuer: target_issuer,
        profile_id: profile&.id,
        profile_verified_at: profile&.verified_at,
        profile_requested_issuer: profile&.initiating_service_provider_issuer,
        returned_at: Time.zone.now,
      )
    end

    def target
      @target ||= ServiceProvider.find_by!(issuer: target_issuer)
    end
  end
end
