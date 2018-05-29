require 'cloudhsm_jwt'

class IdTokenBuilder
  include Rails.application.routes.url_helpers

  JWT_SIGNING_ALGORITHM = 'RS256'.freeze
  NUM_BYTES_FIRST_128_BITS = 128 / 8

  attr_reader :identity

  def initialize(identity:, code:, custom_expiration: nil)
    @identity = identity
    @code = code
    @custom_expiration = custom_expiration
  end

  def id_token
    CloudhsmJwt.encode(jwt_payload)
  end

  private

  attr_reader :code

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
      at_hash: hash_token(identity.access_token),
      c_hash: hash_token(code),
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
    ttl = Pii::SessionStore.new(identity.rails_session_id).ttl
    Time.zone.now.to_i + ttl
  end

  def hash_token(token)
    leftmost_128_bits = Digest::SHA256.digest(token).byteslice(0, NUM_BYTES_FIRST_128_BITS)
    Base64.urlsafe_encode64(leftmost_128_bits, padding: false)
  end
end
