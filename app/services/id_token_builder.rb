# frozen_string_literal: true

class IdTokenBuilder
  JWT_SIGNING_ALGORITHM = 'RS256'
  NUM_BYTES_FIRST_128_BITS = 128 / 8

  attr_reader :identity, :now

  # @param actor [Hash, nil] RFC 8693 §4.1 `act` (actor) claim. When present the
  #   issued token expresses delegation: the actor is acting on behalf of the
  #   subject. Exchanged tokens have no authorization code, so `c_hash` is
  #   omitted whenever an actor is given.
  def initialize(identity:, code:, custom_expiration: nil, now: Time.zone.now, actor: nil)
    @identity = identity
    @code = code
    @custom_expiration = custom_expiration
    @now = now
    @actor = actor
  end

  def id_token
    JWT.encode(
      jwt_payload,
      AppArtifacts.store.oidc_primary_private_key,
      'RS256',
      kid: JWT::JWK.new(AppArtifacts.store.oidc_primary_private_key).kid,
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
      acr:,
      aud: identity.service_provider,
      jti: SecureRandom.urlsafe_base64,
      at_hash: hash_token(identity.access_token),
    }
    if @actor
      # An exchanged token has no authorization request to bind to: no nonce
      # (some clients reject an explicit null) and no authorization code.
      claims[:act] = @actor
    else
      claims[:nonce] = identity.nonce
      claims[:c_hash] = hash_token(code)
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

  def determine_ial_max_acr
    if identity.user.identity_verified?
      Component::AcrComponentValues::IAL2
    else
      Component::AcrComponentValues::IAL1
    end
  end

  def resolved_authn_context
    @resolved_authn_context ||= AuthnContextResolver.new(
      user: identity.user,
      service_provider: identity.service_provider_record,
      acr_values: identity.acr_values,
    )
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
