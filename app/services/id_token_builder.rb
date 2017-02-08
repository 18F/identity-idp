class IdTokenBuilder
  include Rails.application.routes.url_helpers

  JWT_SIGNING_ALGORITHM = 'RS256'.freeze

  attr_reader :identity

  def initialize(identity, custom_expiration: nil)
    @identity = identity
    @custom_expiration = custom_expiration
  end

  def id_token
    JWT.encode(jwt_payload, RequestKeyManager.private_key, JWT_SIGNING_ALGORITHM)
  end

  private

  def jwt_payload
    OpenidConnectUserInfoPresenter.new(identity).user_info.
      merge(id_token_claims).
      merge(timestamp_claims)
  end

  def id_token_claims
    {
      acr: acr,
      nonce: identity.nonce,
      aud: identity.service_provider,
      jti: SecureRandom.urlsafe_base64,
    }
  end

  def timestamp_claims
    now = Time.zone.now.to_i
    {
      exp: @custom_expiration || expires,
      iat: now,
      nbf: now,
    }
  end

  def acr
    ial = identity.ial
    case ial
    when 1
      Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
    when 3
      Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF
    else
      raise "Unknown ial #{ial}"
    end
  end

  def expires
    ttl = Pii::SessionStore.new(identity.session_uuid).ttl
    Time.zone.now.to_i + ttl
  end
end
