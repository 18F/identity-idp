class IdTokenBuilder
  JWT_SIGNING_ALGORITHM = 'RS256'.freeze
  NUM_BYTES_FIRST_128_BITS = 128 / 8

  attr_reader :identity, :now

  def initialize(identity:, code:, custom_expiration: nil, now: Time.zone.now)
    @identity = identity
    @code = code
    @custom_expiration = custom_expiration
    @now = now
  end

  def id_token
    JWT.encode(
      jwt_payload,
      AppArtifacts.store.oidc_private_key,
      'RS256',
      kid: JWT::JWK.new(AppArtifacts.store.oidc_private_key).kid,
    )
  end

  private

  attr_reader :code

  def jwt_payload
    OpenidConnectUserInfoPresenter.new(identity, session_accessor: session_accessor).
      user_info.
      merge(id_token_claims).
      merge(timestamp_claims)
  end

  def id_token_claims
    {
      acr: acr,
      nonce: identity.nonce,
      aud: identity.service_provider,
      jti: SecureRandom.urlsafe_base64,
      at_hash: hash_token(identity.access_token),
      c_hash: hash_token(code),
    }
  end

  def timestamp_claims
    {
      exp: @custom_expiration || expires,
      iat: now.to_i,
      nbf: now.to_i,
    }
  end

  def acr
    ial = identity.ial
    case ial
    when Idp::Constants::IAL_MAX then Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF
    when Idp::Constants::IAL1 then Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
    when Idp::Constants::IAL2 then Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
    else
      raise "Unknown ial #{ial}"
    end
  end

  def expires
    now.to_i + session_accessor.ttl
  end

  def hash_token(token)
    leftmost_128_bits = Digest::SHA256.digest(token).byteslice(0, NUM_BYTES_FIRST_128_BITS)
    Base64.urlsafe_encode64(leftmost_128_bits, padding: false)
  end

  def session_accessor
    @session_accessor ||= OutOfBandSessionAccessor.new(identity.rails_session_id)
  end
end
