# frozen_string_literal: true

class IdTokenBuilder
  JWT_SIGNING_ALGORITHM = 'RS256'
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

  def ttl
    session_accessor.ttl
  end

  private

  attr_reader :code

  def jwt_payload
    OpenidConnectUserInfoPresenter.new(identity, session_accessor: session_accessor)
      .user_info
      .merge(id_token_claims)
      .merge(timestamp_claims)
  end

  def id_token_claims
    claims = {
      nonce: identity.nonce,
      aud: identity.service_provider,
      jti: SecureRandom.urlsafe_base64,
      at_hash: hash_token(identity.access_token),
      c_hash: hash_token(code),
    }

    if !sp_requests_vot?
      claims[:acr] = acr
    end

    claims
  end

  def timestamp_claims
    {
      exp: @custom_expiration || session_accessor.expires_at.to_i,
      iat: now.to_i,
      nbf: now.to_i,
    }
  end

  def acr
    return nil unless identity.acr_values.present?
    resolved_authn_context.asserted_ial_acr
  end

  def sp_requests_vot?
    return false unless identity.vtr.present?
    IdentityConfig.store.use_vot_in_sp_requests
  end

  def vot
    return nil unless sp_requests_vot?
    resolved_authn_context.result.component_values.map(&:name).join('.')
  end

  def determine_ial_max_acr
    if identity.user.identity_verified?
      Vot::AcrComponentValues::IAL2
    else
      Vot::AcrComponentValues::IAL1
    end
  end

  def resolved_authn_context
    @resolved_authn_context ||= AuthnContextResolver.new(
      user: identity.user,
      service_provider: identity.service_provider_record,
      vtr: parsed_vtr_value,
      acr_values: identity.acr_values,
    )
  end

  def parsed_vtr_value
    return nil unless sp_requests_vot?
    JSON.parse(identity.vtr)
  end

  def expires
    now.to_i + ttl
  end

  def hash_token(token)
    leftmost_128_bits = Digest::SHA256.digest(token).byteslice(0, NUM_BYTES_FIRST_128_BITS)
    Base64.urlsafe_encode64(leftmost_128_bits, padding: false)
  end

  def session_accessor
    @session_accessor ||= OutOfBandSessionAccessor.new(identity.rails_session_id)
  end
end
