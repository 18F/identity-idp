# frozen_string_literal: true

module TokenExchange
  class AccessTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

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

      EncryptedRedisStructStorage.store(access_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
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
      }
    end

    def target
      @target ||= ServiceProvider.find_by!(issuer: target_issuer)
    end
  end
end
