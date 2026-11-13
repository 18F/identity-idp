# frozen_string_literal: true

module TokenExchange
  class AccessTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, :delegation_id, keyword_init: true)

    ACCESS_TOKEN_TYPE = 'at+jwt'
    JWT_CONTENT_TYPE = 'JWT'

    def self.issue(subject_token:, target_issuer:, resource:, scope:, dpop_jkt: nil)
      new(
        subject_token:,
        target_issuer:,
        resource:,
        scope:,
        dpop_jkt:,
      ).issue
    end

    def initialize(subject_token:, target_issuer:, resource:, scope:, dpop_jkt:)
      @subject_token = subject_token
      @target_issuer = target_issuer
      @resource = resource
      @scope = scope
      @dpop_jkt = dpop_jkt
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
        actor_issuer: subject_token.actor_issuer,
        target_issuer:,
        resource:,
        scope:,
        dpop_jkt:,
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
          actor_issuer: subject_token.actor_issuer,
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

    attr_reader :subject_token, :target_issuer, :resource, :scope, :dpop_jkt

    # A Nested JWT (RFC 7519 section 5.2): the JWE header says `cty: JWT` so the agency knows to
    # verify a signed token inside, rather than read the plaintext as claims.
    def jwe(issued_at:, expires_at:)
      OpenidConnect::JweEncryptor.encrypt(
        jwt(issued_at:, expires_at:),
        service_provider: target,
        cty: JWT_CONTENT_TYPE,
      )
    end

    # The inner token is typed `at+jwt` (RFC 9068 section 2.1) so a verifier can never mistake
    # it for an ID token signed by the same key, and vice versa.
    def jwt(issued_at:, expires_at:)
      JWT.encode(
        payload(issued_at:, expires_at:),
        AppArtifacts.store.oidc_primary_private_key,
        IdTokenBuilder::JWT_SIGNING_ALGORITHM,
        kid: JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid,
        typ: ACCESS_TOKEN_TYPE,
      )
    end

    # RFC 9068 section 2.2: `jti` identifies this one token (RFC 7519 section 4.1.7) so the agency
    # can refuse a repeat, and `client_id` names the actor the token was issued to, which `act.sub`
    # (RFC 8693 section 4.1) also records as the party acting for the person.
    def payload(issued_at:, expires_at:)
      {
        iss: IdentityConfig.store.domain_name,
        sub: target_identity.uuid,
        aud: target_issuer,
        exp: expires_at,
        iat: issued_at,
        jti: SecureRandom.uuid,
        client_id: subject_token.actor_issuer,
        scope:,
        act: {
          sub: subject_token.actor_issuer,
        },
        **confirmation_claim,
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

    # RFC 9449 §6.1 (and RFC 7800): a token bound to the actor's key carries the key's RFC 7638
    # thumbprint as `cnf.jkt`, so the agency can require a proof signed by that key on every
    # request and refuse the token presented as a bearer token. A bearer token carries no `cnf`.
    def confirmation_claim
      return {} if dpop_jkt.blank?

      { cnf: { jkt: dpop_jkt } }
    end

    def target
      @target ||= ServiceProvider.find_by!(issuer: target_issuer)
    end

    def target_identity
      @target_identity ||= begin
        user = ServiceProviderIdentity.find_by(
          uuid: subject_token.identity_uuid,
          service_provider: subject_token.actor_issuer,
        ).user

        ServiceProviderIdentity.find_by(user:, service_provider: target_issuer)
      end
    end
  end
end
