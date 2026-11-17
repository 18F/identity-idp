# frozen_string_literal: true

class AccessTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model

  validate :validate_access_token

  SCHEMES = %w[Bearer DPoP].freeze

  def initialize(http_authorization_header, dpop_proof: nil, http_method: nil, http_url: nil)
    @http_authorization_header = http_authorization_header
    @dpop_proof = dpop_proof
    @http_method = http_method
    @http_url = http_url
    @identity = nil
  end

  # The P-256 public key the verified proof was signed with, when the token is DPoP-bound; the
  # key the user-information response seals a site key to (RFC 9449 §4.2, the proof's jwk header).
  attr_reader :dpop_public_key

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
        dpop_bound: @identity.present? && dpop_required?,
      },
    )

    [response, (success ? @identity : nil)]
  end

  def error_message
    (errors[:access_token] + errors[:dpop_proof]).join(' ')
  end

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

  def validate_binding(scheme, access_token)
    return validate_bearer_scheme(scheme) unless dpop_required?

    unless scheme == 'DPoP'
      return refuse_binding('invalid_token', 'dpop_bearer_presented', :dpop_bearer_presented)
    end

    bound_thumbprint = AccessTokenBinding.load(access_token)&.dpop_jkt
    if bound_thumbprint.blank?
      return refuse_binding('invalid_token', 'dpop_token_unbound', :dpop_token_unbound)
    end

    validate_dpop_proof(access_token:, bound_thumbprint:)
  end

  def validate_bearer_scheme(scheme)
    return if scheme == 'Bearer'

    errors.add(
      :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
      type: :malformed_authorization
    )
  end

  def validate_dpop_proof(access_token:, bound_thumbprint:)
    form = DpopProofForm.new(
      proof: dpop_proof,
      http_method:,
      http_url:,
      access_token:,
      expected_thumbprint: bound_thumbprint,
    )
    result = form.submit
    @dpop_public_key = form.public_key if result.success?
    return if result.success?

    dpop_error = result.errors[:proof].first
    refuse_binding('invalid_dpop_proof', dpop_error, dpop_error.to_sym)
  end

  def refuse_binding(error, message, type)
    @dpop_error = error
    errors.add(:dpop_proof, message, type:)
  end

  def dpop_required?
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
