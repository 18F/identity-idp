# frozen_string_literal: true

class AccessTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model

  validate :validate_access_token

  # Which `Authorization` schemes a token may arrive under (RFC 6750 §2.1, RFC 9449 §7.1).
  SCHEMES = %w[Bearer DPoP].freeze

  # The DPoP proof, method and URL describe the request the token arrived with; they are read only
  # when the token belongs to a client Login.gov lists for key binding.
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
        dpop_bound: (true if @identity && bound_client?),
        dpop_error_type: errors.details[:dpop_proof]&.first&.dig(:type),
      },
    )

    [response, (success ? @identity : nil)]
  end

  # The reason the token was refused, for the response body.
  def error_message
    (errors[:access_token] + errors[:dpop_proof]).join(' ')
  end

  # RFC 9449 §7.1: a refusal that concerns a bound token names the DPoP scheme and the algorithms
  # Login.gov accepts, with `invalid_token` for a token presented the wrong way and
  # `invalid_dpop_proof` for a proof that does not verify. Nil for every other refusal.
  def www_authenticate
    return if @dpop_error.nil?

    "DPoP algs=\"#{DpopProofForm::ALLOWED_ALGORITHMS.join(' ')}\", error=\"#{@dpop_error}\""
  end

  private

  attr_reader :http_authorization_header, :dpop_proof, :http_method, :http_url

  def validate_access_token
    scheme, access_token = extract_access_token(http_authorization_header)
    return if access_token.blank?

    load_identity(access_token)
    validate_binding(scheme, access_token) if @identity
  end

  # A token of a client Login.gov lists for key binding is served only under the DPoP scheme with
  # a proof for this request signed by the key the sign-in named (RFC 9449 §7.1); presented as a
  # Bearer token it is refused. The key is read from the record written with the token for the
  # token's lifetime, never from the identity. A token of any other client is a bearer token as it
  # always was, and the DPoP scheme is not accepted from it.
  def validate_binding(scheme, access_token)
    unless bound_client?
      return if scheme == 'Bearer'

      return errors.add(
        :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
        type: :malformed_authorization
      )
    end

    bound_thumbprint = AccessTokenBinding.load(access_token)&.dpop_jkt
    if bound_thumbprint.blank?
      return refuse_binding(
        'invalid_token', 'dpop_token_unbound',
        :dpop_token_unbound
      )
    end
    unless scheme == 'DPoP'
      return refuse_binding(
        'invalid_token', 'dpop_bearer_presented',
        :dpop_bearer_presented
      )
    end

    result = DpopProofForm.new(
      proof: dpop_proof,
      http_method:,
      http_url:,
      access_token:,
      expected_thumbprint: bound_thumbprint,
    ).submit
    return if result.success?

    refuse_binding(
      'invalid_dpop_proof', result.first_error_message, result.extra[:dpop_error_type]
    )
  end

  # `error` is the RFC 9449 §7.1 challenge code: `invalid_token` when a bound token is presented
  # the wrong way, `invalid_dpop_proof` when the proof itself does not verify.
  def refuse_binding(error, message, type)
    @dpop_error = error
    errors.add(:dpop_proof, message, type:)
  end

  def bound_client?
    @identity.service_provider_record&.dpop_required? == true
  end

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

  def extract_access_token(header)
    if header.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.no_authorization'),
        type: :no_authorization
      )
      return
    end

    scheme, access_token = header.split(' ', 2)
    if !SCHEMES.include?(scheme) || access_token.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
        type: :malformed_authorization
      )
      return
    end

    [scheme, access_token]
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
