# frozen_string_literal: true

# Authenticates a request to the user-information endpoints from its `Authorization` header: the
# token must be a service provider's own access token for a sign-in that is still live.
#
# Two authorization schemes are read. `Bearer` (RFC 6750) is how a confidential client presents
# its token, and nothing about that path changes for it. `DPoP` (RFC 9449 §7.1) is how a public
# client presents a token bound to a key it holds: the request must also carry a `DPoP` proof
# signed by that key, for this method and URL, with `ath` over the token. A bound token presented
# as a bearer token is refused, as is a bearer token presented under the DPoP scheme, so a token
# copied out of a browser is useless to anyone without the key. Refusals that concern key binding
# carry a `WWW-Authenticate: DPoP` challenge (RFC 9449 §7.1, RFC 6750 §3) telling the client
# which scheme and algorithms to use.
class AccessTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model

  BEARER_SCHEME = 'Bearer'
  DPOP_SCHEME = 'DPoP'
  SCHEMES = [BEARER_SCHEME, DPOP_SCHEME].freeze

  validate :validate_access_token

  # @return [String, nil] the `WWW-Authenticate` value for a refusal that concerns key binding;
  #   nil for every other outcome
  attr_reader :www_authenticate

  # @param http_authorization_header [String, nil] the `Authorization` request header
  # @param dpop_proof [String, nil] the `DPoP` request header, read only for a bound token
  # @param http_method [String, nil] method of the request, for the proof's `htm`
  # @param http_url [String, nil] absolute URL of the request, for the proof's `htu`
  def initialize(http_authorization_header, dpop_proof: nil, http_method: nil, http_url: nil)
    @http_authorization_header = http_authorization_header
    @dpop_proof = dpop_proof
    @http_method = http_method
    @http_url = http_url
    @identity = nil
  end

  # @return [Array(FormResponse, ServiceProviderIdentity), Array(FormResponse, nil)]
  def submit
    success = valid?

    response = FormResponse.new(
      success:,
      errors:,
      extra: {
        client_id: @identity&.service_provider,
        ial: @identity&.ial,
        integration_errors:,
      },
    )

    [response, (@identity if success)]
  end

  private

  attr_reader :http_authorization_header, :dpop_proof, :http_method, :http_url

  def validate_access_token
    scheme, access_token = extract_access_token(http_authorization_header)
    return if access_token.nil?

    load_identity(access_token)
    verify_key_binding(scheme, access_token) if @identity
  end

  # A token is accepted only if it is a service provider's own access token: the lookup is
  # against `identities` and nothing else. Delegated tokens issued by token exchange are not
  # identities rows (they live in DelegatedTokenStore), so they are never found here and
  # userinfo never releases a person's attributes to the holder of one; an agency learns about
  # the person only through introspection. Do not add a second lookup path.
  def load_identity(access_token)
    identity = ServiceProviderIdentity.find_by(access_token: access_token)

    if identity && OutOfBandSessionAccessor.new(identity.rails_session_id).ttl.positive?
      @identity = identity
    else
      errors.add(
        :access_token, t('openid_connect.user_info.errors.not_found'),
        type: :not_found
      )
    end
  end

  # Reads the scheme and token from the `Authorization` header. An unknown scheme or an empty
  # token is malformed, as it always has been.
  # @return [Array(String, String), nil]
  def extract_access_token(header)
    if header.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.no_authorization'),
        type: :no_authorization
      )
      return
    end

    scheme, access_token = header.split(' ', 2)
    if SCHEMES.exclude?(scheme) || access_token.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
        type: :malformed_authorization
      )
      return
    end

    [scheme, access_token]
  end

  # The scheme must match the token's binding, and a bound token must come with a proof from its
  # key (RFC 9449 §7.1). A bearer token under the Bearer scheme has nothing to verify here.
  def verify_key_binding(scheme, access_token)
    if @identity.dpop_jkt.blank?
      return if scheme == BEARER_SCHEME

      refuse(
        :token_not_bound, 'invalid_token', t('openid_connect.user_info.errors.token_not_bound')
      )
    elsif scheme != DPOP_SCHEME
      refuse(
        :bound_token_requires_dpop, 'invalid_token',
        t('openid_connect.user_info.errors.bound_token_requires_dpop')
      )
    else
      result = DpopProofVerifier.new(
        proof: dpop_proof,
        http_method:,
        http_url:,
        access_token:,
        expected_thumbprint: @identity.dpop_jkt,
      ).call
      refuse(result.error_type, 'invalid_dpop_proof', result.error_message) unless result.success?
    end
  end

  # Records a key-binding refusal with its RFC 9449 §7.1 challenge. The identity stays known for
  # analytics but is never handed to the caller.
  def refuse(type, error, message)
    @www_authenticate =
      %(#{DPOP_SCHEME} algs="#{DpopProofVerifier::ALLOWED_ALGORITHMS.join(' ')}", error="#{error}")
    errors.add(:access_token, message, type:)
  end

  def integration_errors
    {
      error_details: errors.full_messages,
      error_types: errors.attribute_names,
      event: :oidc_bearer_token_auth,
      integration_exists: @identity&.service_provider.present?,
      request_issuer: @identity&.service_provider,
    }
  end
end
