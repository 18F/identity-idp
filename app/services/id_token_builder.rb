class IdTokenBuilder
  include Rails.application.routes.url_helpers

  attr_reader :identity

  def initialize(identity, custom_expiration: nil)
    @identity = identity
    @custom_expiration = custom_expiration
  end

  def id_token
    payload = {
      iss: root_url,
      aud: identity.service_provider,
      sub: identity.uuid,
      acr: acr,
      nonce: identity.nonce,
      jti: '', # a unique identifier for the token which can be used to prevent reuse of the token
    }.merge(id_token_timestamp_values)

    JWT.encode(payload, RequestKeyManager.private_key, 'RS256')
  end

  private

  def id_token_timestamp_values
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
