# frozen_string_literal: true

module TokenExchange
  class AccessTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    def self.issue(subject_token:, target_issuer:, resource:, scope:)
      new(
        subject_token:,
        target_issuer:,
        resource:,
        scope:,
      ).issue
    end

    def initialize(subject_token:, target_issuer:, resource:, scope:)
      @subject_token = subject_token
      @target_issuer = target_issuer
      @resource = resource
      @scope = scope
    end

    def issue
      expires_in = IdentityConfig.store.token_exchange_access_token_expires_in
      issued_at = Time.zone.now.to_i
      expires_at = issued_at + expires_in
      delegation_id = DelegatedIssuance.generate_delegation_id
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

      DelegatedIssuance.transaction do
        target_return_log = create_target_return_log
        DelegatedIssuance.create!(
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
      end
      EncryptedRedisStructStorage.store(access_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :subject_token, :target_issuer, :resource, :scope

    def jwe(issued_at:, expires_at:)
      public_key = target.ssl_certs.first.public_key
      jwk = JWT::JWK.new(public_key)

      JWE.encrypt(
        jwt(issued_at:, expires_at:),
        public_key,
        typ: 'JWT',
        zip: 'DEF',
        alg: 'RSA-OAEP',
        enc: 'A256GCM',
        kid: jwk.kid,
      )
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
      }
    end

    def create_target_return_log
      billed_ial = IalContext.new(
        ial: Idp::Constants::IAL_MAX,
        service_provider: target,
        user: target_identity.user,
      ).bill_for_ial_1_or_2
      profile = target_identity.user.active_profile if billed_ial > 1

      SpReturnLog.create!(
        request_id: SecureRandom.uuid,
        user: target_identity.user,
        billable: true,
        ial: billed_ial,
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

    def target_identity
      @target_identity ||= begin
        user = ServiceProviderIdentity.find_by(
          uuid: subject_token.identity_uuid,
          service_provider: subject_token.broker_issuer,
        ).user

        ServiceProviderIdentity.find_by(user:, service_provider: target_issuer)
      end
    end
  end
end
