# frozen_string_literal: true

class AccessTokenVerifier
  include ActionView::Helpers::TranslationHelper
  include ActiveModel::Model

  validate :validate_access_token

  def initialize(http_authorization_header)
    @http_authorization_header = http_authorization_header
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

    [response, @identity]
  end

  private

  attr_reader :http_authorization_header

  def validate_access_token
    access_token = extract_access_token(http_authorization_header)
    load_identity(access_token) if access_token
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

    bearer, access_token = header.split(' ', 2)
    if bearer != 'Bearer' || access_token.blank?
      errors.add(
        :access_token, t('openid_connect.user_info.errors.malformed_authorization'),
        type: :malformed_authorization
      )
      return
    end

    access_token
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
